# Architecture

Application architecture and implementation conventions for Digibujo — a digital Bullet Journal built on Rails 8, Hotwire, and SQLite.

Framework-agnostic references live in [`docs/`](docs/). Agent workflow rules live in [`AGENTS.md`](AGENTS.md).

## Authentication

Custom session-based auth built with an `Authentication` concern (not Devise). **Passwordless:** users continue with email + one-time code (`LoginCode`). `AuthenticationController#create` finds or creates the `User`, sends a code, and stores `session[:login_email]`; `Authentications::ConfirmationsController#create` verifies the code and always starts a session, then redirects to the app. `OnboardingController` (authenticated) still exists: `Onboarding#complete` provisions `Loose Notes` and the single `Daylog`. Monthlylog / Future remain opt-in. Logout via `DELETE /authentication`. Persisted sessions live in the `sessions` table; the signed httponly cookie holds `session_id`. `Current.user` / `Current.session` via `ActiveSupport::CurrentAttributes`. Controllers opt out of auth with `allow_unauthenticated_access`. The continue-with-email form links to **`GET /features`** (`FeaturesController#show`) and **`GET /support`** (`SupportController#show`), both unauthenticated with `layout: public`. Rate limiting is applied to authentication create, confirmation create, and onboarding create. Auth forms use a `form-submit` Stimulus controller for submit loading state.

## User Settings

Per-user settings live in a dedicated `user_settings` table (one row per user), accessed via `User::Configurable` concern. `User` `has_one :settings, class_name: "User::Settings"`; the row is created automatically on user create. `User::Settings` exposes typed columns and a `SECTIONS` / `SECTION_COLUMNS` map (current sections: `logs`, `projects`, `collections`, `published` → `*_expanded` booleans). **`appearance`** (`default`, `warm`, `cool`, `nature`, `cheese`) drives the home background tint. Add new settings as real columns and extend the model; avoid JSON columns. Home section expand/collapse is updated via `POST /home/sections/:id/expand` and `POST /home/sections/:id/collapse` (`Home::SectionsController`), which guards unknown keys using `User::Settings::SECTION_COLUMNS`. Appearance is updated via `POST /home/appearance` (`Home::AppearancesController`). The concern also exposes `User#settings!` which lazy-creates the row on first access; use it from controllers so users created before the row existed (or created via raw SQL) still get a settings record.

## Delegated Type Pattern (Bullets)

`Bullet` uses `delegated_type :bulletable` with `inverse_of: :bullet` for polymorphism. The `bullets` table holds `bulletable_type`/`bulletable_id`. Implemented bulletable types:

| Type    | Concerns     | Notes                              |
|---------|--------------|------------------------------------|
| `Task`  | `Bulletable` | Completable + temporal; plain `body` text |
| `Note`  | `Bulletable` | Long-form; Action Text/Lexxy `body` |
| `Event` | `Bulletable` | Temporal; plain `body`; date range |
| `Voice` | `Bulletable` | Audio memo; plain caption `body` |

Each bulletable includes **`Bulletable`** (`has_one :bullet`, display defaults, `to_partial_path` / `to_form_path`, `permitted_bullet_attributes`). **Note alone** declares `has_rich_text :body` (Action Text via Lexxy). Task/Event/Voice store a plain **`body` text column**. **`Bulletable#name` / `#excerpt`** default from `body`; Note overrides for rich text. **`Bullet` delegates `:body`** (and type-specific display helpers) to the bulletable. Create/update params nest body under `bulletable_attributes`.

**Composers:** type partials via `Bullet#to_form_path` (`tasks/form`, `notes/form`, …) wrap a thin layout shell [`bullets/_form`](app/views/bullets/_form.html.erb) (`form_with`, hiddens, rail; Stimulus wiring lives on the form shell / type locals, not on the model). Task/Event/Voice use a plain `text_field`; Note uses Lexxy preset **`note`**. Rendered note rich text uses `.rich-text-content` alongside Lexxy's `.lexxy-content`. **Projects** sync from Action Text `#` attachables **only on Notes**. Each type declares permitted attributes via `permitted_bullet_attributes`.

**Bucket membership:** `Bullet` **requires** `belongs_to :bucket` (Daylog, Monthlylog, Future, or Collection). **`bucket_id` must belong to the same user** and must be supplied on create (composer hidden field / `new` query params). Homes are exclusive: the daylog page never unions monthly/future bullets. **`Migratable#migrate_to!`** moves a bullet to a destination with an explicit BuJo `action` (`collected` or `rescheduled`) and a caller-resolved `pops_on`. **`Collectable#collect!`** and **`Postponable#postpone!`** own destination/`pops_on` rules and call that API. There is no uncollect — migration is one-way.

### Composer UX

All bullet types are created via **`POST /bullets`** (`BulletsController`) — there are no nested `daylog/bullets` or `monthlylogs/:id/bullets` routes.

**Dock** (`bullets/composer/_dock.html.erb`): type buttons stay in the page; each link loads `GET /bullets/new` into a **page-level `<dialog>`** turbo-frame (`bullets/composer/_dialog`, built on `shared/dialog` + `dialog` Stimulus). Desktop uses a compact dialog; mobile styles it as a **bottom sheet** (keyboard-safe). Successful create keeps the dialog open and clears the form; Esc / cancel / backdrop closes the dialog and clears the frame. **`attemptDismiss`** (double-Esc confirm) applies only to Note (Lexxy) composers.

**Monthly spread / Future:** no dock. Planned cells: Task + Event; unplanned: Task + Note — links load into the page dialog frames.

## Bullet row rendering

List views use **`<%= render partial: bullet.to_partial_path, locals: { bullet: bullet } %>`**, which resolves `Bullet#to_partial_path` → type row (`tasks/task`, `notes/note`, …) with local name forced to `:bullet`. Each type row wraps layout [`bullets/_bullet`](app/views/bullets/_bullet.html.erb) (turbo-frame, inline marker + migration metadata) and yields type-specific content.

- **Wrappers:** `reviews/_bullet`, `monthlylogs/bullets/_bullet`, `futures/bullets/_bullet` — drag shells around the type row render.

## Bullet Status

`Bullet` has a `pinned` boolean column (`default: false, null: false`). Archive state is **not** a column — it lives in a separate polymorphic `Archive` entity (see **Archive entity** below). There is no `status` enum. `Pinnable` adds a `pinned` scope and `pin!` / `unpin!` helpers (used by bullets and buckets; no pin count limit). **`Archivable`** adds `archived` / `active` scopes backed by the `archives` join. Daylog and other list views use the **`active`** scope to hide archived bullets; pinned bullets remain visible and are distinguished by icons in the marker.

`Bullet` tracks **`migrated_at`** (`datetime`, nullable) and **`last_migration`** (json, default `{}`). BuJo moves go through **`Migratable#mark_migration!`** with action `collected` or `rescheduled` (and matching Activity). **`mark_as_reviewed!`** and **`Task#complete!`** only set `migrated_at` (and clear `last_migration` on review) so the bullet leaves the review inbox — they are not BuJo migration actions. Archiving does **not** stamp `migrated_at`. `migrated?` is `migrated_at.present?`. Row markers use `collected_migration?` / `rescheduled_migration?` plus `migration_hint`. Project tags do **not** stamp migration.

## Archive entity

Archiving (`Bullet` or `Bucket`) is modelled as a row in **`archives`** (`archivable_type` / `archivable_id` polymorphic, `user_id`, timestamps), mirroring `PinnedEntity`. A unique index guarantees at most one `Archive` per subject. `Archive#created_at` replaces the old `archives_on` column; `Archive#user_id` records who archived.

**`Archivable`** (shared concern on Bullet and Bucket) provides `has_one :archive`, `archived` / `active` / `expired_archived` scopes, and `archive!` / `unarchive!` (create/destroy the join row only). Lifecycle side effects live on **`Archive`**:

- `after_create` records Activity with **`subject: Archive`**, action `archived`, metadata snapshot (`name`)
- `before_destroy` records `unarchived` the same way (skipped when the Archive is destroyed via `dependent:` on the archivable)
- `after_create_commit` / `after_destroy_commit` call `archivable.reindex` so search stays in sync (archive is not an `update!` on the subject)

`Bullet::Searchable` and `Bucket::Searchable` both use `searchable? { !archived? }`. Review inbox scopes **`.active`** (and `migrated_at: nil`) so archived bullets leave review without a migration stamp. `archives_on` remains a shim (`archive&.created_at&.to_date`) for views and tests.

## Activity

`Activity` is a polymorphic audit log: **`subject`** (`Bullet`, `Bucket`, or `Archive`), **`action`** (string from a flat `Activity::ACTIONS` list), **`metadata`** (json), **`user_id`**. Recording goes through **`ActivityTrackable#record_activity!`** on subjects, except archive/unarchive which are written from `Archive` callbacks. Actions: `updated`, `collected`, `rescheduled`, `completed`, `uncompleted`, `pinned`, `unpinned`, `project_mentioned` / `project_unmentioned`, `created`, `destroyed`, `archived`, `unarchived`. Bucket `created` is recorded from controllers (collections/monthlylogs); `destroyed` from `CleanSoftDeletedRecordsJob` before hard delete (snapshots `name` / `colour` / `bucketable_type`); pin stays on intent methods/controllers. Bucket activities are retained after hard delete so `destroyed` rows remain until swept. BuJo migrate intents (`postpone!` → `rescheduled`, `collect!` → `collected`) write bullet activities with migration payload in `metadata`. Complete records Activity `completed` and sets `migrated_at` only; **`mark_as_reviewed!`** sets `migrated_at` with no Activity. Feed copy is built by **`ActivitiesHelper#activity_sentence`** (links via `polymorphic_path`). **`GET /activities`** lists the user's global feed (no subject filter). **`GET /activities/compact`** returns the latest six activities for the home rail.

## Tracker

`Tracker` is a habit grid **on a Monthlylog** (`belongs_to :monthlylog`). One mark per calendar day via **`Tracker::Completion`**. Not a bullet — no archive or sweep. Identity uses **`Colourable`** / **`Iconable`**.

**Schedule** (`schedule` json): `{ "days" => […] }` with Ruby `wday` 0–6 (defaults to every day). Active range is the monthlylog period. No `stop!` lifecycle — delete the tracker or leave it for the month.

**UI:** create from monthlylog show (`POST /monthlylogs/:id/trackers`). Show page renders that month’s day cells. Toggle posts to `POST`/`DELETE /trackers/:id/completion`.

## Mood tracker

Optional day-level artifacts on **Daylog**: **`Daylog::MoodEntity`** (`daylog_mood_entities`: `date` + mood enum) and **`Daylog::Picture`** (`daylog_pictures`: `date` + Active Storage `image`). Mark/clear via `POST`/`DELETE /daylog/mood_entity` and `POST`/`DELETE /daylog/picture`. Monthly show reads the same records for its spread days (mood controls + photo thumbs). Notes no longer carry mood.

## Review

**`GET /review`** (`ReviewsController#show`, `?from=YYYY-MM-DD&to=YYYY-MM-DD`, defaults to the last 7 days through today) lists bullets that still need triage for the period:

```ruby
Current.user.bullets
  .active
  .where(bucket_id: daylog_bucket.id, pops_on: @review_from..@review_to, migrated_at: nil)
```

- **Daylog home only** — monthly/future/collection bullets are excluded.
- **`pops_on` must be set** — unplanned bullets (`pops_on` nil) are excluded.
- **Already migrated / reviewed** bullets are excluded (`migrated_at` set by pop, collect, complete, or `mark_as_reviewed!`).
- **Archived** bullets are excluded via the **`active`** scope.

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

Logs are **independent** buckets — no FK ownership between Future, Monthlylog, and Daylog. Controllers resolve “current” records with inline queries (`futures.covering(date)`, `monthlylogs.covering(date)` / `find_by(period_from:)`, `user.daylog`).

**Future** — optional six-month park (`period_from` month start; `period_to` auto end of month 6). `spread_months` lists the six month-starts. Manual create: **`GET/POST /futures`**. Single **`show`**: month card-grid + unplanned on the same page (desktop = mobile). Sometime → covering Future when one exists. No overlap checks between Futures.

**Monthlylog** — optional one calendar month (`period_from` / auto `period_to`). `spread_days` lists each day. Top-level create: **`GET/POST /monthlylogs`**. **`GET /monthlylog`** → current month or empty. Single **`show`**: two panels side by side — days stacked vertically (date rail links to daylog) + unplanned (no tabs). Styles in `monthlylog.css` (`monthlylog--*`), separate from Future’s card-grid in `future.css`.

**Daylog** — **one per user** (`has_one :daylog`), provisioned in `Onboarding#complete` alongside Loose Notes. Day slice is **`pops_on`**. **`GET /daylog`**: if missing (legacy / destroyed), `show` renders a create form (`POST /daylog` → re-runs `Onboarding#complete`); if present, lists that day’s bullets. Day-level mood/photo via **`Daylog::MoodEntity`** / **`Daylog::Picture`**. Call sites that need the daylog bucket read `user.daylog.bucket` (no lazy ensure). Create always requires an explicit `bucket_id`. Daylog name/icon constants live on `Onboarding` (`DAYLOG_NAME`, `DAYLOG_ICON`).

## Organizing from the timeline

Select bullets via the marker checkbox inlined in **`bullets/_bullet.html.erb`** (and monthly/future drag wrappers) — `bullet--marker` label over a screen-reader checkbox with `data-bulk-menu-target="checkbox"`. The sticky **`_bulk_menu`** (styled in `bulk-menu.css`, driven by `bulk-menu` Stimulus on the page wrapper) keeps selection in **`idListValue`** and syncs a comma-separated `bullet_ids` CSV into every `data-bulk-menu-target="idList"` hidden field.

**Direct intents (no UI fetch):** **pin**, **archive**, **mark reviewed** (on review pages) — `POST`/`DELETE` with `turbo_stream` from menu forms.

**UI fetch then intent:** **Later** (postpone) and **Save** (collect) — `openPopsPicker` / `openCollectsPicker` set frame `src` with `bullet_ids` from `idListValue`, then `showPopover()` (lazy turbo-frame + popover, like pinned footer); picker POST/search forms use `data-bulk-menu-target="idList"` (synced on `idListTargetConnected` and `idListValueChanged`). Collect picker search reloads via GET with `q`; **create collection** link passes `bullet_ids` and `return_to` to `new_collection_path`. Menu embeds search inline via `menu/_search` + combobox (`GET /search`, turbo-stream for live input); menu shell is `GET /menu`. Lexxy `#` / `@` suggestions use `filter`.

**Postpone intent:** `POST /bullets/postpone` with required `bucket_id` and optional `pops_on`. Date options send Daylog + date; **This month** sends current Monthlylog when it exists (`pops_on` nil); **Sometime** sends covering Future when it exists (`pops_on` nil). Monthly/Future/review drops always pass an explicit `bucket_id`. **Collect intent:** `POST /bullets/collect` with `bucket_id` migrates into a collection (no uncollect). Pin/Unpin and complete/uncomplete hide based on selection state. Activity records `rescheduled`, `collected`, `completed`, `pinned`, and `unpinned` where applicable (`mark_as_reviewed!` does not create an Activity).

`Collectable` / `Postponable` resolve destination and `pops_on`, then call **`Migratable#migrate_to!`** with an explicit action; they do not convert bullet type. Archive remains a separate soft-delete entity (not a bucket).

## Sweep Rules

`CleanSoftDeletedRecordsJob` runs daily and purges expired archived records:

- **`Bullet.expired_archived.destroy_all`** — hard-deletes archived bullets after `Archivable::RETENTION_DAYS` (30 days); pinned bullets are excluded
- **`Bucket.expired_archived.destroy_all`** — hard-deletes archived buckets after `Archivable::RETENTION_DAYS` (30 days); pinned buckets are excluded; bullets belonging to the bucket are destroyed with it

**`SweepActivityLogsJob`** runs daily and deletes activities older than `Activity::RETENTION_DAYS` (30 days).

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

## Projects (tags)

`Project` is a first-class model (`belongs_to :user`) with `name` and `colour`. Shared behaviour: `Colourable`, `Pinnable`, `ActionText::Attachable`. Mark is fixed (`#` → hash icon). Bullets link via `bullet_projects` (many-to-many). Surface: `GET /projects`. Lexxy `#` prompt exists **only on the Note composer**. Pin/unpin uses `projects/pin` on the show page.

Projects link via `bullet_projects` (many-to-many). Body attachable sync (`sync_projects_from_body!`) runs **only for Notes**. Explicit add/remove intents are deferred to a future API.

## Buckets and memberships

`Bucket` belongs to a user and uses `delegated_type :bucketable` (`Collection`, `Future`, `Monthlylog`, `Daylog`). Every bullet has exactly one `bucket_id` (required).

| Type | Role | `pops_on` |
|------|------|-----------|
| Daylog | Daily rapid log (1 per user) | Required (day slice) |
| Monthlylog | Optional monthly spread | Day cell or nil |
| Future | Optional six-month park | nil = unplanned; month start in spread |
| Collection | Topical park | Always nil |

Bucket **identity** (`name`, `colour`, `icon`, optional `description`) lives on `buckets`. Collection names are unique per user. Home hub: `GET /home` (also **`root`**).

**Collection archive:** all bucket types are archivable (`Bucket#archive!` / `#unarchive!` via `Archivable`). `DELETE /collections/:id` soft-archives the bucket by inserting an `Archive` row; archived collections are hidden from home, review collect panel, and collect picker (`collections.merge(Bucket.active)`). Collect into an archived bucket is rejected (`Collectable` uses the `.active` scope, surfacing 404). Activity records `archived` / `unarchived` with subject `Archive`. Purge after retention is handled by `CleanSoftDeletedRecordsJob` (see Sweep Rules).

## Pinned workspace

Desktop footer has a single **Pinned** button (pin icon) in [`shared/_footer.html.erb`](app/views/shared/_footer.html.erb) (`#pinned_dock`). Clicking opens a lazy popover (`turbo-frame#pinned_list`) that loads a flat list of all pinned entities (Bullet, Bucket, Project) via [`pinned#index`](app/controllers/pinned_controller.rb) with `Turbo-Frame: pinned_list`. Mobile uses the bottom tab bar via [`shared/_footer.html+mobile.erb`](app/views/shared/_footer.html+mobile.erb) and **`GET /pinned`** for the same flat list in full-page mode (with bulk menu for bullets). Pin/unpin Turbo Streams replace bullet rows (`render "bullets/bullet"`) and entity pin buttons only — the footer button is static.

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

# Trackers (nested create under monthlylog; show/edit on tracker)
POST   /monthlylogs/:monthlylog_id/trackers  → monthlylogs/trackers#create
resources :trackers, only: %i[show edit update destroy]
  nested: trackers/:tracker_id/completion     → trackers/completions#create/destroy
POST   /daylog/mood_entity                   → daylogs/mood_entities#create
DELETE /daylog/mood_entity                   → daylogs/mood_entities#destroy
POST   /daylog/picture                       → daylogs/pictures#create
DELETE /daylog/picture                       → daylogs/pictures#destroy

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
