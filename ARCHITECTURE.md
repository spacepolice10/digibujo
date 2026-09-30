# Architecture

Application architecture and implementation conventions for Dotted — a digital Bullet Journal built on Rails 8, Hotwire, and SQLite. One infinite timeline, collections, and a quiet Upcoming screen.

Framework-agnostic references live in [`docs/`](docs/). Agent workflow rules live in [`AGENTS.md`](AGENTS.md).

## Authentication

Custom session-based auth built with an `Authentication` concern (not Devise). **Passwordless:** users continue with email + one-time code (`AuthCode`). `AuthenticationController#create` finds or creates the `User`, sends a code, and stores `session[:login_email]`; `Authentications::ConfirmationsController#create` calls `AuthCode.consume!` and always starts a session, then redirects to `onboarding#new` unless `user.onboarded?`, otherwise to the app. `OnboardingController` (authenticated) sets `users.onboarded` through `Onboarding#complete` and, when asked, seeds sample bullets and collections. Logout via `DELETE /authentication`. Persisted sessions live in the `sessions` table; the signed httponly cookie holds `session_id`. `Current.user` / `Current.session` via `ActiveSupport::CurrentAttributes`. Controllers opt out of auth with `allow_unauthenticated_access`. The continue-with-email form links to **`GET /features`** (`FeaturesController#show`) and **`GET /support`** (`SupportController#show`), both unauthenticated with `layout: public`. Rate limiting is applied to authentication create, confirmation create, and onboarding create. Auth forms use a `form-submit` Stimulus controller for submit loading state.

### JSON API (CLI / integrations)

Same routes, `Accept: application/json` / `.json` suffix (Fizzy-style; no `/api` namespace).

**CSRF:** HTML forms stay protected. JSON requests **without** a `Sec-Fetch-Site` header skip the authenticity token (curl/CLI). Browsers always send `Sec-Fetch-Site`, so browser-origin JSON still needs CSRF.

**Auth**

1. **`POST /authentication.json`** `{ "email_address": "…" }` → **201** `{ "pending_authentication_code": "…" }` (httponly cookie set too); invalid email → **422**; rate limit → **429**.
2. **`POST /authentication/confirmation.json`** `{ "code": "…", "pending_authentication_code": "…" }` → **200** `{ "session_code": "…", "onboarded": bool }`; bad/missing codes → **401**. Uses `AuthCode` for the emailed one-time code.
3. **`DELETE /authentication.json`** → **204**.

Subsequent requests authenticate via, in order: signed `session_id` cookie (browser); **`Authorization: Bearer`** — `AccessCode` digest lookup first, then short-lived `session_code` from magic-link confirm (15 min expiry; so a CLI can mint an `AccessCode` without a cookie jar). Unauthenticated JSON → **401** `{ "error": "Unauthorized" }` (HTML redirects to sign-in). Browsers use `session_id`; CLIs use an `AccessCode` (or briefly Bearer `session_code` to create one). Session and pending-auth cookies are httponly, `SameSite=Lax`, and `Secure` in production.

**Access codes** (hashed at rest; plaintext only on create):

- HTML: **Account → Access codes** (`GET /access_codes`) — list prefixes and revoke; create is JSON/CLI only
- JSON: `GET/POST /access_codes.json`, `DELETE /access_codes/:id.json`
- Create body: `{ "access_code": { "description" } }` → **201** includes `code` once (`dj_…`). Every access code has full API access for that user.
- Index returns `id`, `code_prefix`, `description`, `created_at` (never digest/plaintext `code`)
- Managing access codes requires a session or an existing access code.

**Timeline bullets:** `GET /timeline/bullets.json?before=<id>` — cursor paging; **200** array, **204** exhausted/unknown, **304** when `If-None-Match` matches ETag. **Create:** `POST /bullets.json` → **201** + `Location` + bullet body; validation → **422**. Bullet JSON: `id`, `bulletable_type`, `pops_on`, `collection_id`, `done`, `archived`, `author_name`, `body`, `body_html`, `duration_seconds` (memos), timestamps, `url`.

**Hooks** (inbound intake for external apps → timeline):

- Manage (session or access code): HTML **Account → Hooks** — index lists hooks + Create; **`GET /hooks/new`** form (payload docs); create shows intake URL once via flash on index. JSON `GET/POST /hooks.json`, `DELETE /hooks/:id.json`. Create body: `{ "hook": { "name" } }` → **201** with `code` once (`hk_…`) and `url` (`POST /hooks/:code`).
- Intake (unauthenticated): `POST /hooks/:code` with `{ "author_name", "bulletable_type", "body" }` → creates a `Text` bullet on that user's timeline (today, no collection). The only allowed type is `Text`. **201** + bullet JSON; unknown/inactive code → **404**; bad type/validation → **422**. The intake `code` is hashed at rest (same pattern as access codes) but only authorizes bullet create — not full API access.

## User Settings

Per-user settings live in a dedicated `user_settings` table (one row per user), accessed via `User::Configurable` concern. `User` `has_one :settings, class_name: "User::Settings"`; the row is created automatically on user create. **`appearance`** (`default`, `warm`, `cool`, `nature`, `cheese`) drives the application background tint and is updated via `POST /home/appearance` (`Home::AppearancesController`). Add new settings as real columns and extend the model; avoid JSON columns. The concern also exposes `User#settings!` which lazy-creates the row on first access; use it from controllers so users created before the row existed (or created via raw SQL) still get a settings record. Legacy `*_expanded` columns remain in the table for compatibility but are no longer read by the application.

## Timeline

Dotted is one long **timeline** plus **collections**. Everything a user writes is a `Bullet`; where it shows is decided by two columns:

- **`pops_on`** (`date`, never null, defaults to today) — the day a bullet belongs to.
- **`collection_id`** (nullable FK) — set once the bullet has been filed into a collection.

`Timeline` (plain Ruby, `user.timeline`) is the single feed: `bullets` = the user's `active` bullets with no collection and `pops_on <= today`; `upcoming` = the same with `pops_on > today`. Nothing about sections is stored. `Timeline.section_for(date, today:)` derives a `Timeline::Section` (`key`, `label`) from the bullet's age in days:

| Age (days) | Section |
|------------|---------|
| 0 (or future) | Today |
| 1 | Yesterday |
| 2–6 | One section per day (`Monday, Sep 28`) |
| 7–13 | Last week |
| 14–30 | Last month |
| 31–90 | Last 3 months |
| 91–365 | Last year |
| older | One section per year |

`TimelinesController#show` renders the newest page inside an inverted chat list (`chat--scroller`): oldest at the top, composer docked at the bottom. `TimelinesHelper#timeline_sections` groups the page into `<section id="timeline_section_<key>">` wrappers with a `timeline--label` heading; today's section is always rendered (and hidden by CSS while it holds no bullet) so the composer's turbo stream has a target. `Timelines::BulletsController#index` (`GET /timeline/bullets?before=<id>`) serves the older page in the same markup; a page may end mid-section, so `chat-scroll` merges the incoming last section into the on-screen one of the same id instead of duplicating its heading.

**Upcoming** (`GET /upcoming`, `UpcomingController#show`) lists `timeline.upcoming` grouped by day. It is not linked as the default screen; bullets join the timeline automatically when their day arrives.

**Postponing** only changes `pops_on` (`Postponable#postpone!`, records `rescheduled` with `from_pops_on` / `to_pops_on`). A bullet moved to a future day disappears from the timeline and appears on Upcoming. Collected bullets keep their `pops_on` but live in their collection.

## Delegated Type Pattern (Bullets)

`Bullet` uses `delegated_type :bulletable` with `inverse_of: :bullet`. The `bullets` table holds `bulletable_type`/`bulletable_id`. Two bulletable types exist:

| Type   | Concerns     | Notes                              |
|--------|--------------|------------------------------------|
| `Text` | `Bulletable` | The default; body only |
| `Memo` | `Bulletable` | Voice recording (`has_one_attached :recording`, 1–60 s); optional caption in body |

Each bulletable includes **`Bulletable`** (`has_one :bullet`, display defaults, `to_partial_path`, `permitted_bullet_attributes`). **`Bullet` owns the single rich-text `body`** (`has_rich_text :body`, Action Text/Lexxy — no plain `body` columns anywhere). **`Bullet#body_as_text`** is the `to_plain_text` form; **`#name`** is its first line, **`#long?`** compares it against `EXCERPT_LIMIT`, and **`#excerpt`** dispatches to `bulletable.excerpt_for(body)`. Create/update params carry `body` at the top level (`bullet[body]`); type-specific fields nest under `bulletable_attributes` (Memo recording and duration).

**Every bullet can be done.** `bullets.done_at` (`datetime`, nullable) is owned by the **`Completable`** concern: `complete!` / `uncomplete!` record `completed` / `uncompleted` activity and drop the bullet from search selections. `Bullet#marker_icon` is `:check` when done, otherwise the type's icon (`:square` for Text, `:microphone` for Memo). Rows expose `data-bullet-done`.

**Collections:** `Collectable#collect!(collection_id:)` files a bullet into one of the user's active collections (`collected` activity). There is no uncollect and no per-type conversion.

### Composer UX

All bullets are created via **`POST /bullets`** (`BulletsController`) — there are no nested create routes.

**Composer** ([`bullets/_composer_v2`](app/views/bullets/_composer_v2.html.erb), `composer` Stimulus): one form for the timeline and collection pages. Callers pass the bullet, Lexxy preset, autofocus, an optional `collection` and `pops_on`. Hidden fields carry `bulletable_type` (`Text` enabled, `Memo` disabled until recorder mode) and `collection_id`. Text and voice modes share one submit control; switching modes resets recorder resources cleanly. Multiline and toolbar state live on the composer element and are styled by [`composer_v2.css`](app/assets/stylesheets/composer_v2.css).

**Voice mode:** the recorder partial owns MediaRecorder, microphone cleanup, live waveform, preview playback, and waveform seeking. It dispatches readiness to `composer`, which keeps submit disabled until a take exists.

**Inline create responses:** [`create.turbo_stream.erb`](app/views/bullets/create.turbo_stream.erb) appends the rendered bullet to `timeline_section_today` (timeline bullets due today) or `dom_id(collection)`; a bullet created for another day renders nothing. Failures update the toast host with status 422; plain HTML create redirects to the bullet show.

**Edit:** `GET/PATCH /bullets/:id/edit` is a body-only form; type, collection and `pops_on` are not accepted on update.

## Chat surfaces

Shared list chrome lives in [`chat.css`](app/assets/stylesheets/chat.css): `chat--window`, `chat--surface`, `chat--scroller`, `chat--load-more-trigger`. The Stimulus `chat-scroll` controller owns cursor paging on both the timeline and collection pages. The composer is the final flex row of `.chat--window`; the scroller consumes the remaining height. Viewport meta uses `interactive-widget=resizes-content`, so Chromium/Android shrinks the layout viewport under the keyboard. WebKit/iOS ignores that directive, so `keyboard-spacing` mirrors `visualViewport.height` and `offsetTop` onto the chat window while a composer control is focused.

**Cursor paging** (`Bullet::Pageable`): pages are keyed on the oldest row already on screen, never an offset, because the composer keeps appending to the same list. Collections read by creation time (`last_page` / `page_before`, ties broken on `id`). The timeline reads by day (`last_day_page` / `day_page_before`, ordering on `pops_on`, `created_at`, `id`). Both take `PAGE_SIZE` rows in reading order from the end via `last(n)` (reversed in SQL). The controllers answer **204** once nothing older is left, or for unknown or foreign cursors, and set `@more_bullets` when the first page came back full.

**Scrolling** (`chat-scroll` + [`helpers/scroll_helpers`](app/javascript/helpers/scroll_helpers.js)): open at the bottom with a smooth `scrollTo` (ResizeObserver follow starts after `scrollend` / timeout so it cannot cancel the animation); an `IntersectionObserver` on `.chat--load-more-trigger` fetches the next older page and prepends it inside `keepScroll`, which restores the distance to the bottom edge so the row being read never moves. `pauseInertiaScroll` clamps overflow for a frame first, or iOS momentum would override the write. The observer is re-armed after each prepend, and the loop ends when the new rows push it out of range or the endpoint answers 204. New rows follow the reader only while they are already at the bottom — tracked on every scroll event, deliberately unthrottled.

**Short-list pin (CSS):** `.chat--scroller`'s first row gets an auto start margin, so a sparse list packs against the composer without putting `.chat--load-more-trigger` in view (which would auto-fetch every page).

## Bullet row rendering

List views use **`<%= render partial: bullet.to_partial_path, locals: { bullet: bullet } %>`**, which resolves `Bullet#to_partial_path` → the type row (`texts/text`, `memos/memo`) with local name forced to `:bullet`. Each type row wraps layout [`bullets/_bullet`](app/views/bullets/_bullet.html.erb) (turbo-frame, marker label, selection checkbox) and yields type-specific content. Done bullets set `data-bullet-done="true"` and strike through `.bullet--body`.

## Archive entity

Archiving (`Bullet` or `Collection`) is modelled as a row in **`archives`** (`archivable_type` / `archivable_id` polymorphic, `user_id`, timestamps). A unique index guarantees at most one `Archive` per subject. `Archive#user_id` records who archived.

**`Archivable`** (shared concern on Bullet and Collection) provides `has_one :archive`, `archived` / `active` / `expired_archived` scopes, and `archive!` / `unarchive!` (create/destroy the join row only). Lifecycle side effects live on **`Archive`**:

- `after_create` records Activity with **`subject: Archive`**, action `archived`, metadata snapshot (`name`)
- `before_destroy` records `unarchived` the same way (skipped when the Archive is destroyed via `dependent:` on the archivable)
- `after_create_commit` / `after_destroy_commit` call `archivable.reindex` so search stays in sync

`Bullet::Searchable` and `Collection::Searchable` both use `searchable? { !archived? }`.

## Activity

`Activity` is a polymorphic audit log: **`subject`** (`Bullet`, `Collection`, or `Archive`), **`action`** (string from the flat `Activity::ACTIONS` list), **`metadata`** (json), **`user_id`**. Recording goes through **`ActivityTrackable#record_activity!`** on subjects, except archive/unarchive which are written from `Archive` callbacks. Actions: `updated`, `collected`, `rescheduled`, `completed`, `uncompleted`, `project_mentioned` / `project_unmentioned`, `created`, `destroyed`, `archived`, `unarchived`. Collection `created` is recorded from the controller; `destroyed` from `CleanSoftDeletedRecordsJob` before hard delete (snapshots `name` / `colour`). `collect!` stores `collection_id` and `collection_name`; `postpone!` stores `from_pops_on` and `to_pops_on`. Feed copy is built by **`ActivitiesHelper#activity_sentence`** (links via `polymorphic_path`; dates link to the timeline, or Upcoming when in the future). **`GET /activities`** lists the user's global feed.

## Collections

`Collection` belongs to a user and holds bullets (`has_many :bullets, dependent: :destroy`). Identity (`name`, `colour`, `icon`, optional `description`) lives on the row; names are unique per user (normalized to lowercase). `Colourable`, `Iconable`, `Archivable`, `ActivityTrackable`. `GET /collections/:id` renders the chat surface for the collection (`Collections::BulletsController#index` pages older rows); `GET /collections/:id/export` downloads an HTML export.

**Collection archive:** `DELETE /collections/:id` soft-archives by inserting an `Archive` row; archived collections are hidden from home and the collect picker (`collections.active`). Collect into an archived collection is rejected with a 404. Purge after retention is handled by `CleanSoftDeletedRecordsJob`.

## Organizing from the timeline

Select bullets via the marker checkbox in **`bullets/_bullet.html.erb`** — a `bullet--marker` label over a screen-reader checkbox with `data-bulk-menu-target="checkbox"`. The sticky **`_bulk_menu`** (styled in `bulk-menu.css`, driven by `bulk-menu` Stimulus) keeps selection in **`idListValue`** and syncs a comma-separated `bullet_ids` CSV into every `data-bulk-menu-target="idList"` hidden field. Actions apply to uniform selections through `data-bulk-*` traits on each checkbox: `data-bulk-completable` (`incomplete` / `completed`), `data-bulk-publishable`, and `data-bulk-scheduled` (`today` / `not-today`, so the **Today** action only shows for bullets that are not already on today's timeline).

**Direct intents (no UI fetch):** complete, archive, publish, and Today (a postpone to `Date.current`) — `POST`/`DELETE` with `turbo_stream` from menu forms.

**UI fetch then intent:** **Later** (postpone) and **Save** (collect) — `openPopsPicker` / `openCollectsPicker` set frame `src` with `bullet_ids`, then `showPopover()`; picker forms use `data-bulk-menu-target="idList"`. The schedule picker offers Today, Tomorrow, Next week, Next weekend, Next month, or a date input. The collect picker filters by `q`, and its **create collection** link passes `bullet_ids` and `return_to` to `new_collection_path`. Menu embeds search via `searches/form` + `searches/palette` + combobox (`GET /search`, turbo-stream for live input); menu shell is `GET /menu`. ⌘J opens the menu, ⌘K opens it and focuses search. Lexxy `#` suggestions use `filter`.

**Postpone intent:** `POST /bullets/postpone` with `bullet_ids` and a required `pops_on`. **Collect intent:** `POST /bullets/collect` with `bullet_ids` and `collection_id` (no uncollect). **Completion:** `POST`/`DELETE /bullets/completion`. Postpone and collect responses remove the row; a postpone to today re-appends it to `timeline_section_today`.

## Sweep Rules

`CleanSoftDeletedRecordsJob` runs daily and purges expired archived records:

- **`Bullet.expired_archived.destroy_all`** — hard-deletes archived bullets after `Archivable::RETENTION_DAYS` (30 days)
- **`Collection.expired_archived`** — hard-deletes archived collections after the same window; their bullets are destroyed with them

**`SweepActivityLogsJob`** runs daily and deletes activities older than `Activity::RETENTION_DAYS` (30 days).

## Projects (tags)

`Project` is a first-class model (`belongs_to :user`) with `name` and `colour`. Shared behaviour: `Colourable`, `ActionText::Attachable`. Mark is fixed (`#` → hash icon). Bullets link via `bullet_projects` (many-to-many). Surface: `GET /projects`. Lexxy `#` prompt (`lexxy-prompt` → `GET /projects/suggestions?filter=`) is mounted on the composer. Body attachable sync (`sync_projects_from_body!`) runs for every bulletable type, triggered by the Action Text `body` after_save hook.

## Publishing

Bullets include **`Publishable`**: a `published_entities` row holds a public **`code`**. **`publish!`** / **`unpublish!`** create or destroy that row. **`GET /published`** (authenticated) lists the user's published bullets. **`GET /published/:code`** (unauthenticated, `layout: public`) shows a single published bullet. Publish/unpublish bulk intent: `POST`/`DELETE /bullets/publish`.

## Turbo Streams

Mutating bullet actions (`create`, `update`, `destroy`, and bullet sub-resources) respond to `format.turbo_stream` for inline updates where applicable. HTML fallback redirects are provided. Bulk intents use the shared `_bulk_menu` forms.

## Routes

```
root                                         → timelines#show

# Auth
resource :authentication                    → authentication#new/create/destroy
resource :authentication/confirmation      → authentications/confirmations#new/create
resource :onboarding                        → onboarding#new/create
resource :features                          → features#show (unauthenticated, layout: public)
resource :support                           → support#show (unauthenticated, layout: public)

# Timeline
GET    /timeline                            → timelines#show
GET    /timeline/bullets?before=:id         → timelines/bullets#index (older page, 204 when exhausted)
GET    /upcoming                            → upcoming#show

# Bullets CRUD
GET    /bullets                             → bullets#index
POST   /bullets                             → bullets#create
GET    /bullets/:id                         → bullets#show
GET    /bullets/:id/edit                    → bullets#edit
PATCH  /bullets/:id                         → bullets#update
DELETE /bullets/:id                         → bullets#destroy

# Bullet bulk intents (`bullet_ids` comma-separated)
POST   /bullets/archive                     → bullets/archives#create
DELETE /bullets/archive                     → bullets/archives#destroy
POST   /bullets/collect                     → bullets/collects#create (`collection_id`)
GET    /bullets/collect/new                 → bullets/collects#new
POST   /bullets/postpone                    → bullets/postpones#create (`pops_on`)
GET    /bullets/postpone/new                → bullets/postpones#new
POST   /bullets/completion                  → bullets/completions#create
DELETE /bullets/completion                  → bullets/completions#destroy
POST   /bullets/publish                     → bullets/publishes#create
DELETE /bullets/publish                     → bullets/publishes#destroy

# Collections
resources :collections                       → CRUD
GET    /collections/:id/bullets?before=:id   → collections/bullets#index
GET    /collections/:id/export              → collections/exports#show

# Tags
GET    /projects/suggestions                 → projects/suggestions#index
resources :projects

# Home & navigation
GET    /home                                 → home#show
POST   /home/appearance                      → home/appearances#update
GET    /menu                                 → menu#show
GET    /search                               → searches#show (?q=)
POST   /search/selection                     → searches/selections#create

# Account & integrations
GET    /user                                 → users#show
resources :access_codes                      → index/create/destroy
resources :hooks                             → index/new/create/destroy
POST   /hooks/:code                          → hook_intakes#create (unauthenticated)

# Lists
GET    /activities                           → activities#index
resources :archived, only: :index
GET    /attachments                          → attachments#index
GET    /published                            → published#index
GET    /published/:code                      → published#show (public)

# Health / PWA
GET    /up                                   → rails/health#show
GET    /manifest                              → rails/pwa#manifest
GET    /service-worker                        → rails/pwa#service_worker
```

## Database Strategy

SQLite for all environments. Production uses separate SQLite databases for primary data, Solid Cache, Solid Queue, and Solid Cable — no Redis dependency.

## Asset Pipeline

Propshaft (no Sprockets). JavaScript via Importmap (no Node build step). No CSS framework — custom styles only.

## Key Conventions

- JavaScript: use `==` (not `===`) for equality checks
- Ruby 3.4, Rails 8.1
- Minitest for testing with parallel execution and fixtures
- RuboCop with `rubocop-rails-omakase` defaults
- Kamal for deployment with Thruster for HTTP acceleration
- Solid Queue runs in-process with Puma (`SOLID_QUEUE_IN_PUMA=true`)

### Variables

**Prefer variables over arbitrary data.** Instead of hardcoding values (strings, numbers, colors, URLs, etc.) directly in views, stylesheets, or configs, extract them into named variables:
- CSS: use CSS custom properties (`--variable-name`) defined in a single `:root` block
- Ruby/ERB: use constants, model attributes, or controller-assigned `@variables` — never inline magic values
- Configuration: use Rails credentials, environment variables, or initializers — never inline secrets or environment-specific values

**CSS class naming follows a file-scoped convention.** The first segment of a class name matches the stylesheet filename it lives in (the "block"). Everything after `--` identifies a specific nested element or variant within that block. For example, classes in `date-picker.css` are named `date-picker` (the block), `date-picker--segments-picker` (a nested container), `date-picker--segments-button` (a nested element). Never use a prefix that doesn't correspond to the file it's defined in.

Common blocks (use these class names in markup — not legacy `button-primary`-style hyphenation):

| Stylesheet | Markup classes | Notes |
|------------|----------------|-------|
| `button.css` | **Variants:** `button--primary`, `button--secondary`, `button--tertiary`, `button--accent`, `button--link`, `button--danger` (with `button--secondary`). **Shape:** `button--circle`. **Size:** `button--icon` / `icon-strong` / `icon-subtle`, `button--sm`, `button--lg`. **Width:** `button--wide` | Shared chrome for links and `<button>`; hover/active in `button.css` |
| `utilities.css` | `utilities--sr-only`, `utilities--line-clamp-1`, `utilities--text-sm`, `utilities--contents`, `utilities--handwriting` | Small cross-page helpers only; prefer component/layout classes when possible |
| `layout.css` | `layout--page`, `layout--column`, `layout--header`, `layout--header-actions`, `layout--list`, `layout--list-item`, `layout--main`, `header`, `footer`, `footer--dock` | Page structure and app shell chrome (`shared/_header`, `shared/_footer`) |
| `bucket.css` | `bucket--section-list-item`, `bucket--list-item-marker`, … | List rows for collections, projects and previews (legacy block name; predates collections replacing buckets) |
| `dialog.css` | `dialog`, `dialog--large`, `dialog--header`, `dialog--body`, `dialog--footer` | Native `<dialog>` chrome (shared pickers, etc.) |
| `hotkey-hint.css` | `hotkey-hint`, `hotkey-hint--always` | Keyboard shortcut badges on buttons |
| `bullets-form.css` | `bullets-form`, `bullets-form--rail`, … | Body-only edit form chrome |
| `composer_v2.css` | `composer`, `composer--control`, `composer--submit-button`, … | Shared text/voice composer |
| `timeline.css` | `timeline--section`, `timeline--label`, `timeline--composer` | Timeline sections and the docked composer |
| `bullet.css` | `bullet`, `bullet--body`, `bullet--marker`, … | Shared bullet row chrome |
| `note.css`, `voice.css` | Type-specific body/toolbar classes | Pair with `bullets/_bullet` + `texts/_text` / `memos/_memo` |

Styles are declared in `@layer reset, variables, base, layout, components, utilities` in `application.css`. Import order: `reset` → `variables` → `fonts` → `base` → `layout` → `tabbar` → `utilities` → component stylesheets (`button`, `dialog`, `bullet`, …). The `utilities` layer wins over `components` despite being imported earlier. Tokens live in `variables.css` (`--color-*`, `--shadow-subtle` / `--shadow-base` / `--shadow-strong`, `--z-dialog-backdrop` → `--z-dropdown` → `--z-dialog` → `--z-toast`). Element defaults and keyboard focus rings live in `base.css`; `_reset.css` is browser normalization only.

**CSS: pick the closest existing variable — avoid adding new ones.** When a hardcoded CSS value (font-size, border-radius, font-weight, opacity, icon size, etc.) doesn't exactly match an existing variable, map it to the nearest one from `variables.css` rather than creating a new variable. The variable set is intentionally small and should stay that way. A 1–2px difference is acceptable — consistency across the system matters more than pixel-perfect fidelity to the original arbitrary value. Do not add `line-height` or `letter-spacing` declarations — the reset handles base values.

### Turbo

**Prefer `<turbo-frame>` tags in HTML/ERB over ERB helper alternatives.** Use the raw `<turbo-frame id="...">` element directly rather than `turbo_frame_tag` helpers when writing views. This keeps templates explicit, readable, and framework-agnostic. Use `data-turbo-*` attributes directly on elements rather than wrapping helpers where possible.

**Always consult the Turbo reference** (https://turbo.hotwired.dev/reference/drive) and the Rails guides when implementing Turbo features. Turbo events (`turbo:submit-end`, `turbo:render`, etc.) have specific ordering and guarantees — check docs instead of guessing.

## Reference Projects

Basecamp open-source Rails apps are good references for Rails patterns, Turbo usage, and Stimulus conventions:

- **Fizzy** (github.com/basecamp/fizzy) — Rails patterns, nested routes via `scope module:`
- **Campfire** (github.com/basecamp/campfire) — real-time features, Turbo Streams
- **Writebook** (github.com/basecamp/writebook) — content publishing, form patterns
- **Ruby on Rails** (github.com/rails/rails) — Rails patterns, Turbo usage, Stimulus conventions

Consult these when implementing non-trivial features to see idiomatic Rails/Turbo/Stimulus usage.
