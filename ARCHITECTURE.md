# Architecture

Application architecture and implementation conventions for Digibujo — a digital Bullet Journal built on Rails 8, Hotwire, and SQLite.

Framework-agnostic references live in [`docs/`](docs/). Agent workflow rules live in [`AGENTS.md`](AGENTS.md).

## Authentication

Custom session-based auth built with an `Authentication` concern (not Devise). **Passwordless:** users continue with email + one-time code (`LoginCode`). `AuthenticationController#create` finds or creates the `User`, sends a code, and stores `session[:login_email]`; `Authentications::ConfirmationsController#create` verifies the code and always starts a session. Users without Loose Notes are then sent to `OnboardingController` (authenticated); `Onboarding#complete` provisions `Loose Notes` only. Daylog / Monthlylog / Future are opt-in afterward. Returning users go straight to the app. Logout via `DELETE /authentication`. Persisted sessions live in the `sessions` table; the signed httponly cookie holds `session_id`. `Current.user` / `Current.session` via `ActiveSupport::CurrentAttributes`. Controllers opt out of auth with `allow_unauthenticated_access`. The continue-with-email form links to **`GET /features`** (`FeaturesController#show`) and **`GET /support`** (`SupportController#show`), both unauthenticated with `layout: public`. Rate limiting is applied to authentication create, confirmation create, and onboarding create. Auth forms use a `form-submit` Stimulus controller for submit loading state.

## User Settings

Per-user settings live in a dedicated `user_settings` table (one row per user), accessed via `User::Configurable` concern. `User` `has_one :settings, class_name: "User::Settings"`; the row is created automatically on user create. `User::Settings` exposes typed columns and a `SECTIONS` / `SECTION_COLUMNS` map (current sections: `logs`, `projects`, `collections`, `people`, `trackers`, `published` → `*_expanded` booleans). **`appearance`** (`default`, `warm`, `cool`, `nature`, `cheese`) drives the home background tint. Add new settings as real columns and extend the model; avoid JSON columns. Home section expand/collapse is updated via `POST /home/sections/:id/expand` and `POST /home/sections/:id/collapse` (`Home::SectionsController`), which guards unknown keys using `User::Settings::SECTION_COLUMNS`. Appearance is updated via `POST /home/appearance` (`Home::AppearancesController`). The concern also exposes `User#settings!` which lazy-creates the row on first access; use it from controllers so users created before the row existed (or created via raw SQL) still get a settings record.

## Delegated Type Pattern (Bullets)

`Bullet` uses `delegated_type :bulletable` with `inverse_of: :bullet` for polymorphism. The `bullets` table holds `bulletable_type`/`bulletable_id`. Implemented bulletable types:

| Type    | Concerns     | Notes                              |
|---------|--------------|------------------------------------|
| `Task`  | `Bulletable`, `PlainBodyBulletable` | Completable + temporal; plain `body` text |
| `Note`  | `Bulletable` | Long-form; Action Text/Lexxy `body`; mood enum |
| `Event` | `Bulletable`, `PlainBodyBulletable` | Temporal; plain `body`; date range |
| `Voice` | `Bulletable`, `PlainBodyBulletable` | Audio memo; plain caption `body` |

Each bulletable includes **`Bulletable`** (`has_one :bullet`, display defaults, `to_partial_path` / `to_form_path`, `permitted_bullet_attributes`). **Note alone** declares `has_rich_text :body` (Action Text via Lexxy). Task/Event/Voice store a plain **`body` text column** and include **`PlainBodyBulletable`** (`name` / `excerpt` from the string column + update activity). **`Bullet` delegates `:body`** (and type-specific display helpers) to the bulletable. Legacy create/update params may still pass `body:` on the bullet — `Bullet#assign_attributes` / `#body=` forward to the bulletable.

**Composers:** type partials via `Bullet#to_form_path` (`tasks/form`, `notes/form`, …) wrap a thin layout shell [`bullets/_form`](app/views/bullets/_form.html.erb) (`form_with`, hiddens, rail; Stimulus wiring lives on the form shell / type locals, not on the model). Task/Event/Voice use a plain `text_field`; Note uses Lexxy preset **`note`**. Rendered note rich text uses `.rich-text-content` alongside Lexxy's `.lexxy-content`. **Mentions** sync from Action Text attachables **only on Notes**. Note mood picker submits `bulletable_attributes[:mood]` through `accepts_nested_attributes_for :bulletable`; each type declares permitted attributes via `permitted_bullet_attributes`.

**Bucket membership:** `Bullet` **requires** `belongs_to :bucket` (Daylog, Monthlylog, Future, or Collection). **`bucket_id` must belong to the same user**. Homes are exclusive: the daylog page never unions monthly/future bullets. **`Migratable#migrate_to!`** moves a bullet to a destination bucket (with per-type `pops_on` rules). **`Collectable#collect!`** and **`Postponable#postpone!`** wrap that API. There is no uncollect — migration is one-way.

### Composer UX

All bullet types are created via **`POST /bullets`** (`BulletsController`) — there are no nested `daylog/bullets` or `monthlylogs/:id/bullets` routes.

**Daylog dock** (`bullets/composer/_dock.html.erb`): type buttons load `GET /bullets/new` into a page-local turbo-frame via **`composer-picker`** Stimulus. View Transitions wrap dock ↔ form swaps (`app/javascript/helpers/view_transition.js`). Successful create keeps the form open and clears it for the next bullet; **`composer:restore`** (Esc / cancel) returns the dock to the type-picker state.

**Monthly spread dialog** (`monthlylogs/_composer_dialog.html.erb`): a `<dialog>` driven by **`composer-dialog`** Stimulus; turbo-frame id `bullet_composer`. Type links target `turbo_frame: "bullet_composer"`.

**Form marker:** `data-composer-form` on the form element lets `composer-picker` detect the transition from dock buttons into the editor.

## Bullet row rendering

List views use **`<%= render_bullet(bullet) %>`**, which resolves `Bullet#to_partial_path` → type row (`tasks/task`, `notes/note`, …) with local name forced to `:bullet`. Each type row wraps layout [`bullets/_bullet`](app/views/bullets/_bullet.html.erb) (turbo-frame, inline marker + migration metadata) and yields type-specific content.

- **Wrappers:** `reviews/_bullet`, `monthlylogs/bullets/_bullet`, `futures/bullets/_bullet` — drag shells around `render_bullet`.

## Bullet Status

`Bullet` has a `pinned` boolean column (`default: false, null: false`). Archive state is **not** a column — it lives in a separate polymorphic `Archive` entity (see **Archive entity** below). There is no `status` enum. `Pinnable` adds a `pinned` scope and `pin!` / `unpin!` helpers (used by bullets and buckets; no pin count limit). `Bullet::Archivable` (namespaced concern) adds `archived` / `active` scopes backed by the `archives` join. Daylog and other list views use the **`active`** scope to hide archived bullets; pinned bullets remain visible and are distinguished by icons in the marker.

`Bullet` tracks **`migrated_at`** (`datetime`, nullable) and **`last_migration`** (json, default `{}`): set by **`Migratable#mark_migration!`** when the user schedules (postpone with destination change), collects, completes, archives, or marks as reviewed. **`Migratable#mark_as_reviewed!`** stamps `action: 'acknowledged'` when the user keeps a bullet unchanged during review. `migrated?` drives the `›` marker on bullet rows. Full history lives in **`activities.metadata`** (same payload shape). Project/person tags do **not** stamp migration.

## Archive entity

Archiving (`Bullet` or `Bucket`) is modelled as a row in **`archives`** (`archivable_type` / `archivable_id` polymorphic, `user_id`, timestamps), mirroring `PinnedEntity`. A unique index guarantees at most one `Archive` per subject. `Archive#created_at` replaces the old `archives_on` column; `Archive#user_id` records who archived.

State access is split into two **namespaced** concerns (no shared module — Bullet and Bucket diverge too much for one concern):

- **`Bullet::Archivable`** — `has_one :archive`, `archived` / `active` / `expired_archived` scopes, `archive!` (writes `Archive` row + `mark_migration!(action: 'archived', …)`), `unarchive!` (destroys row + `unarchived` activity).
- **`Bucket::Archivable`** — same shape but `archive!` / `unarchive!` record `archived` / `unarchived` activities directly with `bucketable_type` metadata; also calls `reindex` so `Searchable` cache stays in sync (the bucket row is not `update!`-ed, so `after_update_commit :update_in_search_index` does not fire on its own).

Because archive/unarchive is now an INSERT/DELETE into `archives` (not an `update!` of the subject), archive activity is recorded exactly once inside `archive!` / `unarchive!`. `archives_on` is exposed as a shim (`archive&.created_at&.to_date`) for views and tests.

## Activity

`Activity` is a polymorphic audit log: **`subject`** (`Bullet` or `Bucket`), **`action`** (string), **`metadata`** (json), **`user_id`**. Recording goes through **`ActivityTrackable#record_activity!`** on subjects. Bullet actions: `updated`, `collected`, `postponed` (legacy `popped`), `migrated`, `archived`, `unarchived`, `completed`, `uncompleted`, `acknowledged`, `pinned`, `unpinned`, `project_mentioned` / `project_unmentioned`, `person_mentioned` / `person_unmentioned`. Bucket actions: `created`, `updated`, `pinned`, `unpinned`, `archived`, `unarchived`, `destroyed`. Bucket `created` is recorded from controllers (collections/monthlylogs); `destroyed` from `CleanSoftDeletedRecordsJob` before hard delete (snapshots `name` / `colour` / `bucketable_type`); archive/pin stay on their intent methods/controllers. Bucket activities are retained after hard delete so `destroyed` rows remain until `Activity.sweep`. Migration intents write bullet activities with migration payload in `metadata`. **`GET /activities`** lists the user's global feed (no subject filter). **`GET /activities/compact`** returns the latest six activities for the home rail.

## Tracker

`Tracker` tracks repeating habits per user (`belongs_to :user`). One mark per calendar day via **`Tracker::Completion`** (`tracker_id`, `date`, unique index). Not a bullet — no bucket, migration, or sweep. Identity uses **`Colourable`** / **`Iconable`** (`colour`, `icon` columns) like collections.

**Schedule** (`schedule` json): `{ "days" => […] }` with Ruby `wday` 0–6. **Lifecycle:** `active_from` is the creation date; `stopped_on` (nullable) retires the habit. While open, the upper bound is today. **`stop!`** sets `stopped_on`; `POST /trackers/:tracker_id/stop` (`Trackers::StopsController`). Destroy removes completions (`dependent: :destroy`).

**API on the record:** after `Current.user.trackers.open.chronological.with_completions`, views call `tracker.completed?(date)` and `tracker.statistics` (streak, best streak, total, period % over `active_from..active_to`). No separate tracker/query PORO.

**UI:** `resources :trackers, except: :index` (home is the entry point; show/edit/destroy per tracker). Show page renders a **90-day heatmap** (`Date.current - 89.days..Date.current`); create/edit form includes colour + icon pickers like collections. Toggle posts to `POST`/`DELETE /trackers/:id/completion` with `date` + `dom_key`; turbo-stream replaces only that cell.

## Review

**`GET /review`** (`ReviewsController#show`, `?from=YYYY-MM-DD&to=YYYY-MM-DD`, defaults to the last 7 days through today) lists bullets that still need triage for the period:

```ruby
Current.user.bullets
  .where(bucket_id: daylog_bucket.id, pops_on: @review_from..@review_to, migrated_at: nil)
```

- **Daylog home only** — monthly/future/collection bullets are excluded.
- **`pops_on` must be set** — unplanned bullets (`pops_on` nil) are excluded.
- **Already migrated / reviewed** bullets are excluded (`migrated_at` set by pop, collect, archive, complete, or `mark_as_reviewed!`).

**Mark as reviewed:** `POST /bullets/mark_as_reviewed` (`Bullets::MarkAsReviewedsController#create`) calls `mark_as_reviewed!` on all matching bullets (or a `bullet_ids` subset). Redirects back to review. Footer **Mark all as reviewed** and bulk-menu **Mark reviewed** (when `@review_from` / `@review_to` are set via `ApplicationHelper#bulk_menu_review_period`) post here.

**Review UI (desktop, `show.html.erb`, ≥800px):** 3-column workspace in `review.css`:

| Column | Frame / route | Behaviour |
|--------|-------------|-----------|
| Collections (left) | Lazy `turbo-frame#review_collections_frame` → `GET /review/collections` | Paginated list + combobox search; drop → collect via `collect-drop` |
| To review (center) | Inline in `show` | Paginated inbox; draggable bullets + bulk-menu; footer marks all reviewed |
| Schedule (right) | Lazy `turbo-frame#review_scheduled_frame` → `GET /review/scheduled` | 7 days forward from `review_to` (`review_to..review_to+6`); `.active` bullets per day; drop → postpone via `pops-drop` with `reviewDrop` |

Side partials: `reviews/_collections_side`, `reviews/_to_review`, `reviews/_calendar_side` / `_calendar_date`.

**Mobile** (`show.html+mobile.erb`): inbox list + bulk-menu only (no side columns, no per-row action chrome). Drop handlers POST with optimistic client removal; collect drop still accepts turbo-stream responses (errors re-render via stream). Pops drop uses `X-Requested-With: review-pops-drop` / `pops-drop`; pops controller returns `head :no_content` for drop requests.

## Logs (optional Future / Monthlylog, single Daylog)

Logs are **independent** buckets — no FK ownership between Future, Monthlylog, and Daylog. Controllers resolve “current” records with inline queries (`futures.covering(date)`, `monthlylogs.find_by(period_from:)`, `user.daylog`).

**Future** — optional six-month park (`period_from` month start; `period_to` auto end of month 6). Manual create: **`GET/POST /futures`**. Show: unplanned (`pops_on` nil) + month columns. Sometime → covering Future when one exists. No overlap checks between Futures.

**Monthlylog** — optional one calendar month (`period_from` / auto `period_to`). Top-level create: **`GET/POST /monthlylogs`**. **`GET /monthlylog`** → current month or empty. Not nested under Future.

**Daylog** — **one per user** (`has_one :daylog`). Day slice is **`pops_on`**. **`GET /daylog`**: if missing, `show` renders a create form (`POST /daylog`); if present, lists that day’s bullets. `User#ensure_daylog_bucket!` find-or-creates only for mutations (postpone, bullet default home, review drops) — not on daylog show.

## Organizing from the timeline

Select bullets via the marker checkbox inlined in **`bullets/_bullet.html.erb`** (and monthly/future drag wrappers) — `bullet--marker` label over a screen-reader checkbox with `data-bulk-menu-target="checkbox"`. The sticky **`_bulk_menu`** (styled in `bulk-menu.css`, driven by `bulk-menu` Stimulus on the page wrapper) keeps selection in **`idListValue`** and syncs a comma-separated `bullet_ids` CSV into every `data-bulk-menu-target="idList"` hidden field.

**Direct intents (no UI fetch):** **pin**, **archive**, **mark reviewed** (on review pages) — `POST`/`DELETE` with `turbo_stream` from menu forms.

**UI fetch then intent:** **Later** (postpone) and **Save** (collect) — `openPopsPicker` / `openCollectsPicker` set frame `src` with `bullet_ids` from `idListValue`, then `showPopover()` (lazy turbo-frame + popover, like pinned footer); picker POST/search forms use `data-bulk-menu-target="idList"` (synced on `idListTargetConnected` and `idListValueChanged`). Collect picker search reloads via GET with `q`; **create collection** link passes `bullet_ids` and `return_to` to `new_collection_path`. Menu embeds search inline via `menu/_search` + combobox (`GET /search`, turbo-stream for live input); menu shell is `GET /menu`. Lexxy `#` / `@` suggestions use `filter`.

**Postpone intent:** `POST /bullets/postpone` with required `bucket_id` and optional `pops_on`. Date options send Daylog + date; **This month** sends current Monthlylog when it exists (`pops_on` nil); **Sometime** sends covering Future when it exists (`pops_on` nil). Monthly/Future/review drops always pass an explicit `bucket_id`. **Collect intent:** `POST /bullets/collect` with `bucket_id` migrates into a collection (no uncollect). Pin/Unpin and complete/uncomplete hide based on selection state. Activity records `postponed` (legacy `popped` still readable in hints), `collected`, `migrated`, `acknowledged`, `pinned`, and `unpinned` where applicable.

`Collectable` / `Postponable` wrap **`Migratable#migrate_to!`** (optional `action:`); they do not convert bullet type. Archive remains a separate soft-delete entity (not a bucket).

## Sweep Rules

`CleanSoftDeletedRecordsJob` runs daily and purges expired archived records:

- **`Bullet.expired_archived.destroy_all`** — hard-deletes archived bullets after `Bullet::Archivable::RETENTION_DAYS` (30 days); pinned bullets are excluded
- **`Bucket.expired_archived.destroy_all`** — hard-deletes archived buckets after `Bucket::Archivable::RETENTION_DAYS` (30 days); pinned buckets are excluded; bullets belonging to the bucket are destroyed with it

**`SweepActivityLogsJob`** runs daily and calls **`Activity.sweep`** — deletes activities older than `Activity::RETENTION_DAYS` (30 days).

Bullet auto-archive (grace window, completed → archive row) is **not implemented yet** — the job no longer calls the missing `Bullet.auto_archivable` scope.

Planned bullet recycling (not yet in code):

- completed bullets remain recyclable through their archive row (set by future auto-archive logic)
- bullets are auto-archived when due or still untriaged after a grace window
- pinned bullets are excluded from auto-archive

## Analog BuJo Alignment

The architecture is intentionally closer to analog Bullet Journal behavior:

- **Rapid logging** uses type-specific composers (`tasks/_form`, `events/_form`, `voices/_form`, `notes/_form`) wrapping `bullets/_form`; Task/Event/Voice are plain text; Note uses Lexxy preset `note`; daylog dock and monthly dialog load the form via turbo-frame
- **Daily focus** is explicit (`/daylog` and dated daylog paths show the daily log)
- **Migration over rewrite** happens where needed by editing or changing bullet type
- **Deferred decisions** are supported by moving `pops_on` forward (postpone) or tagging a project
- **Separation of concerns** mirrors BuJo pages: today/timeline, archived, pinned

## Mentions (tags)

`Mention` is a first-class model (`belongs_to :user`) with `name`, `colour`, and `kind` (`project` | `person`). Shared behaviour: `Colourable`, `Pinnable`, `ActionText::Attachable`. No per-tag icons or contact fields — the kind mark is fixed (`#` → hash icon, `@` → at icon). Bullets link via `bullet_mentions` (many-to-many). Home and routes keep two surfaces: `GET /projects` / `GET /people` scope `Mention.project` / `Mention.person`. Lexxy `#` / `@` prompts exist **only on the Note composer**. Pin/unpin uses `projects/pin` and `people/pin` on the corresponding show pages.

Kind config (trigger, mark, content_type, activity actions) lives in `Mention::KINDS`. Mentions are added via `Bullet#add_mention!` / removed via `remove_mention!` / `clear_mentions!`. Body attachable sync (`sync_mentions_from_body!`) runs **only for Notes**.

## Buckets and memberships

`Bucket` belongs to a user and uses `delegated_type :bucketable` (`Collection`, `Future`, `Monthlylog`, `Daylog`). Every bullet has exactly one `bucket_id` (required).

| Type | Role | `pops_on` |
|------|------|-----------|
| Daylog | Daily rapid log (1 per user) | Required (day slice) |
| Monthlylog | Optional monthly spread | Day cell or nil |
| Future | Optional six-month park | nil = unplanned; month start in spread |
| Collection | Topical park | Always nil |

Bucket **identity** (`name`, `colour`, `icon`, optional `description`) lives on `buckets`. Collection names are unique per user. Home hub: `GET /home` (also **`root`**).

**Collection archive:** all bucket types are archivable (`Bucket#archive!` / `#unarchive!` via `Bucket::Archivable`). `DELETE /collections/:id` soft-archives the bucket by inserting an `Archive` row; archived collections are hidden from home, review collect panel, and collect picker (`User#active_collections` filters via `Bucket.active`). Collect into an archived bucket is rejected (`Collectable` uses the `.active` scope, surfacing 404). Activity records `archived` / `unarchived` on the bucket. Purge after retention is handled by `CleanSoftDeletedRecordsJob` (see Sweep Rules).

## Pinned workspace

Desktop footer has a single **Pinned** button (pin icon) in [`shared/_footer.html.erb`](app/views/shared/_footer.html.erb) (`#pinned_dock`). Clicking opens a lazy popover (`turbo-frame#pinned_list`) that loads a flat list of all pinned entities (Bullet, Bucket, Mention) via [`pinned#index`](app/controllers/pinned_controller.rb) with `Turbo-Frame: pinned_list`. Mobile uses the bottom tab bar via [`shared/_footer.html+mobile.erb`](app/views/shared/_footer.html+mobile.erb) and **`GET /pinned`** for the same flat list in full-page mode (with bulk menu for bullets). Pin/unpin Turbo Streams replace bullet rows (`render "bullets/bullet"`) and entity pin buttons only — the footer button is static.

## Publishing

Bullets include **`Publishable`**: a `published_entities` row holds a public **`code`**. **`publish!`** / **`unpublish!`** create or destroy that row. **`GET /published`** (authenticated) lists the user's published bullets. **`GET /published/:code`** (unauthenticated, `layout: public`) shows a single published bullet via `PublishedEntity.find_by!(code:)`. Publish/unpublish bulk intent: `POST`/`DELETE /bullets/publish`.

## Turbo Streams

Mutating bullet actions (`create`, `update`, `destroy`, and bullet sub-resources) respond to `format.turbo_stream` for inline updates where applicable. HTML fallback redirects are provided. Bulk intents use the shared `_bulk_menu` forms; selection checkboxes live in the bullet row marker (screen-reader only, toggled via marker label).

## Routes

```
root                                         → home#show

# Auth
resource :authentication                    → authentication#new/create/destroy
resource :authentication/confirmation      → authentications/confirmations#new/create
resource :onboarding                        → onboarding#new/create
resource :features                          → features#show (unauthenticated, layout: public)
resource :support                           → support#show (unauthenticated, layout: public)

# Logs
resource :daylog                            → daylogs#show/create
GET    /monthlylog                      → monthlylogs#current
GET    /futures/:id                  → futures#show
resources :monthlylogs                   → monthlylogs#new/create/show

# Bullets CRUD (no index — daily log is /daylog)
GET    /bullets/:id                         → bullets#show
GET    /bullets/new                         → bullets#new
POST   /bullets                             → bullets#create
GET    /bullets/:id/edit                    → bullets#edit
PATCH  /bullets/:id                         → bullets#update
DELETE /bullets/:id                         → bullets#destroy

# Bullet bulk intents (collection; `bullet_ids` comma-separated)
POST   /bullets/pin                         → bullets/pins#create
DELETE /bullets/pin                         → bullets/pins#destroy
POST   /bullets/archive                     → bullets/archives#create
DELETE /bullets/archive                     → bullets/archives#destroy
POST   /bullets/collect                     → bullets/collects#create (`bucket_id`)
GET    /bullets/collect/new                 → bullets/collects#new
POST   /bullets/postpone                    → bullets/postpones#create (`bucket_id`, optional `pops_on`)
GET    /bullets/postpone/new                → bullets/postpones#new
POST   /bullets/publish                     → bullets/publishes#create
DELETE /bullets/publish                     → bullets/publishes#destroy
POST   /bullets/mark_as_reviewed            → bullets/mark_as_revieweds#create

# Tasks
POST   /tasks/complete                      → tasks/completes#create
DELETE /tasks/complete                      → tasks/completes#destroy

# Collections
resources :collections                       → CRUD (no nested bullets)
GET    /collections/:id/export              → collections/exports#show

# Buckets
GET    /buckets/:id                         → buckets#show (footer popover bullet list)
POST   /buckets/pin                         → buckets/pins#create
DELETE /buckets/pin                         → buckets/pins#destroy

# Tags
GET    /projects/suggestions                 → projects/suggestions#index
POST   /projects/pin                         → projects/pins#create
DELETE /projects/pin                         → projects/pins#destroy
resources :projects
GET    /people/suggestions                   → people/suggestions#index
POST   /people/pin                           → people/pins#create
DELETE /people/pin                           → people/pins#destroy
resources :people

# Trackers
resources :trackers, except: :index
  nested: trackers/:tracker_id/completion     → trackers/completions#create/destroy
  nested: trackers/:tracker_id/stop           → trackers/stops#create

# Home & navigation
GET    /home                                 → home#show
POST   /home/sections/:id/expand             → home/sections#expand
POST   /home/sections/:id/collapse           → home/sections#collapse
POST   /home/appearance                      → home/appearances#update
GET    /menu                                 → menu#show
GET    /search                               → searches#show (?q=)
POST   /search/selection                     → searches/selections#create

# Workspaces
GET    /review                               → reviews#show (?from= &to=YYYY-MM-DD)
GET    /review/collections                   → reviews/collections#index (?from= &to= &q= &collections_page=)
GET    /review/scheduled                     → reviews/scheduled#show (?from= &to=)
GET    /activities                           → activities#index
GET    /activities/compact                   → activities/compact
resources :pinned, only: :index
resources :archived, only: :index
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
- Ruby 3.4.8, Rails 8.1.2
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
| `button.css` | `button--primary`, `button--secondary`, `button--tertiary`, `button--icon`, `button--circle`, `button--danger` (with `button--secondary`), `button--auto`, `button--wide`, `button--sm`, `button--lg` | Shared chrome for links and `<button>`; hover/active in `button.css` |
| `utilities.css` | `utilities--sr-only`, `utilities--line-clamp-1`, `utilities--text-sm`, `utilities--contents`, `utilities--handwriting` | Small cross-page helpers only; prefer component/layout classes when possible |
| `layout.css` | `layout--page`, `layout--column`, `layout--header`, `layout--header-actions`, `layout--list`, `layout--list-item`, `layout--main`, `header`, `footer`, `footer--dock` | Page structure and app shell chrome (`shared/_header`, `shared/_footer`; daylog and bucket pages use `layout--page`) |
| `bucket.css` | `bucket--list`, `bucket--list-item-link`, `bucket--list-item-marker`, … | Bucket list chrome and item styling (pair with `layout--list` / `layout--list-item`) |
| `dialog.css` | `dialog`, `dialog--large`, `dialog--header`, `dialog--body`, `dialog--footer` | Native `<dialog>` chrome (monthly composer, etc.) |
| `hotkey-hint.css` | `hotkey-hint`, `hotkey-hint--always` | Keyboard shortcut badges on buttons |
| `bullet-composer.css` | `bullet-composer`, `bullet-composer--dock`, `bullet--composer-create-button`, … | Composer form and dock type-picker |
| `bullet.css` | `bullet`, `bullet--body`, `bullet--marker`, … | Shared bullet row chrome |
| `task.css`, `note.css`, `event.css`, `voice.css` | Type-specific body/toolbar classes | Pair with `bullets/_bullet` + `{type}s/_{type}` |
| `review.css` | `review--page`, `review--to-review`, `review--calendar`, … | Review workspace columns |

Styles are declared in `@layer reset, variables, base, layout, components, utilities` in `application.css`. Import order: `reset` → `variables` → `fonts` → `base` → `layout` → `tabbar` → `utilities` → component stylesheets (`button`, `dialog`, `bullet`, `review`, …). The `utilities` layer wins over `components` despite being imported earlier. Tokens live in `variables.css` (`--color-*`, `--shadow-subtle` / `--shadow-base` / `--shadow-strong`, `--z-dialog-backdrop` → `--z-dropdown` → `--z-dialog` → `--z-toast`). Element defaults and keyboard focus rings live in `base.css`; `_reset.css` is browser normalization only.

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
