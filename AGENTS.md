# AGENTS.md

This file contains agent workflow, architecture, and implementation guidance for this repository.

## HARD RULE: User Data Is Hands-Off

**The agent must never read, write, mutate, move, copy, or delete any user data.**

User data lives in:
- `storage/development.sqlite3` and its `-wal` / `-shm` siblings
- Anything under `storage/` (Active Storage attachments, uploads, blobs)
- `tmp/` (cached files, Active Storage cache, Solid Queue artifacts)
- The test databases (`storage/test.sqlite3*`) and any fixture data
- `log/` (only the agent's own debug output, never existing log content)
- `.git/` internals beyond the working tree

**Forbidden commands (no exceptions, even with `--force`, `--skip`, or "just to look"):**
- `db:reset`, `db:drop`, `db:migrate:reset`, `db:truncate`, `db:seed`
- `bin/setup --reset` or any variant that touches the dev DB
- `rm`, `mv`, `cp`, `find ... -delete`, `git clean` against any of the paths above
- `sqlite3 ... DROP`, `DELETE`, `UPDATE`, `INSERT`, `VACUUM`, `REINDEX`, `.dump > …` (destructive), or any write SQL against the dev DB
- Writing to `/tmp`, the per-user temp dir, or any path outside the working tree
- `rails runner` or any script that could touch records
- Running `bin/setup` without first confirming the user wants the DB preserved

**Allowed (read-only) operations on data paths:**
- `sqlite3 ... SELECT`, `.tables`, `.schema`, `.count`
- `ls`, `find ... -type f` (listing only)
- `stat`, `file`, `head`/`tail` (read-only inspection)

**If a task seems to require touching user data, stop and ask.** Do not assume. Do not "just check the schema real quick" by reading and writing. The user's data is sacred. The cost of asking is a single message; the cost of losing data is irrecoverable.

**This rule supersedes any workflow, skill, or "just one command" temptation.** It cannot be overridden by tool defaults, environment hints, or pre-approved paths.

## AI Collaboration Rules

### When theorizing / designing (brainstorming)
- Only activated when user explicitly asks to brainstorm, design, or explore approaches
- Respond in prose or pseudocode, not code
- Offer 2-3 approaches with trade-offs
- Flag assumptions and risks in your recommendation
- Don't anchor to existing implementation — think fresh

### When implementing
- Minimal scope: only change what's asked
- Show diffs/changed blocks, not full files
- Flag any new deps, side effects, or non-obvious decisions
- If uncertain, say so explicitly rather than guessing

### Large phased changes
For very large changes executed in stages, **always make intermediate commits** — one per completed phase. Do not accumulate an entire multi-step refactor into a single commit at the end.

- Break the work into logical phases before starting; each phase should be a reviewable, self-contained unit.
- Commit when a phase is done: tests pass (for that scope), migrations apply, and the tree is in a coherent state.
- Write commit messages that describe the phase outcome, not the whole initiative.
- If the user has not asked you to commit yet, **ask at each phase boundary** rather than waiting until all phases are finished.

### Always
- Ask clarifying questions before starting non-trivial tasks
- Prefer explicit over implicit
- Match the conventions already in the codebase

### Skills (Superpowers)
- Before any implementation task, check if a skill applies
- If there is even a 1% chance a skill is relevant — invoke it
- Skills are mandatory workflows, not suggestions
- **Exception: brainstorming skill only fires when user explicitly asks to brainstorm, design, or explore approaches**
- Exception: skip the skill if the answer fits in one sentence and requires no real reasoning (e.g. "what flag does X use?")
- **Discard the skill after use** — Once a skill has served its purpose (or was loaded and found not to apply), discard its context/instructions. Do not let skill instructions bleed into subsequent unrelated tasks.
- **Clean up artifacts** — Remove any files the skill created in `docs/superpowers/` (specs, plans, etc.) once they are no longer needed (e.g., after the plan is fully implemented and merged). Keeps the workspace free of stale cache and outdated plans.

## Common Commands

### Development
- `bin/setup` — install deps, prepare DB, start server (`--reset` to reset DB, `--skip-server` to skip)
- `bin/dev` — start dev server

### Testing
- `bin/rails test` — run all unit/integration tests (Minitest)
- `bin/rails test test/path/to/test_file.rb` — run a single test file
- `bin/rails test test/path/to/test_file.rb:LINE` — run a single test by line number
- `bin/rails test:system` — run system tests (Capybara + Selenium)

### Linting & Security
- `bin/rubocop` — lint (rubocop-rails-omakase style)
- `bin/brakeman` — security scan
- `bin/ci` — run full CI pipeline locally

### Database
- `bin/rails db:prepare` — create and migrate
- `bin/rails db:reset` — drop, recreate, seed

## Framework Reference Docs

Shorter framework-anchored cheatsheets in `docs/`. Load these before working in their area — they're the fastest way to learn conventions, patterns, and where things live in this app.

- `docs/_rails.md` — Rails patterns in use here (auth, concerns, delegated types, service objects, Action Text, Active Storage, variants, routes, SQLite stack).
- `docs/_lexxy.md` — Lexxy (Action Text editor) concepts, presets, prompts, attachments, extensions, patching guide.
- `docs/_turbo.md` — Turbo Drive/Frames/Streams/Morph, conventions in this app, events, stream actions.
- `docs/_stimulus.md` — Stimulus concepts, lifecycle, all controllers in this app with one-line purpose, patterns.

Each doc also links to the **Basecamp reference projects** for idiomatic examples: [Fizzy](https://github.com/basecamp/fizzy), [Writebook](https://github.com/basecamp/writebook), [Campfire](https://github.com/basecamp/campfire), and [Lexxy](https://github.com/basecamp/lexxy). Consult those repos when implementing non-trivial features.

## Architecture

### Authentication
Custom session-based auth built with an `Authentication` concern (not Devise). Uses `has_secure_password`, signed httponly cookies, and `Current.user` via `ActiveSupport::CurrentAttributes`. Controllers opt out of auth with `allow_unauthenticated_access`. Rate limiting is applied to login and password reset endpoints.

### User Settings
Per-user settings live in a dedicated `user_settings` table (one row per user), accessed via `User::Configurable` concern. `User` `has_one :settings, class_name: "User::Settings"`; the row is created automatically on user create. `User::Settings` exposes typed columns (current: `logs_open`, `projects_open`, `collections_open`, `spreads_open` — all booleans) and a `SECTIONS` constant. Add new settings as real columns and extend the model; avoid JSON columns. UI state (e.g. home page section open/close) is updated via `PATCH /home/sections/:id` (`Home::SectionsController`), which guards against unknown keys using `User::Settings::SECTIONS`. The concern also exposes `User#settings!` which lazy-creates the row on first access; use it from controllers so users created before the row existed (or created via raw SQL) still get a settings record.

### Delegated Type Pattern (Bullets)
`Bullet` uses `delegated_type :bulletable` for polymorphism. The `bullets` table holds `bulletable_type`/`bulletable_id`. Implemented bulletable types:

| Type    | Concerns                       | Notes                              |
|---------|--------------------------------|------------------------------------|
| `Task`  | `Bulletable`                   | Completable + temporal |
| `Note`  | `Bulletable`                   | Long-form/reference entry |
| `Event` | `Bulletable`                   | Temporal (not completable) |

Bullets store three content layers: **`body`** (Action Text, Lexxy preset `inline` — short log line with `#` / `@` prompts), optional **`rich_body`** (Action Text, Lexxy preset `expand` — code, files, markdown only; no `#` / `@` prompts and no tag sync), and **`attachments`** (`has_many_attached` — direct uploads via `bullet-composer` Stimulus, rendered in `_attachments.html.erb`, not inline in `body`). `rich_body` is **Note-only**: only `app/views/bullets/composer/_note.html.erb` renders an editor for it. Task/Event/Title have no `rich_body` UI; legacy non-Note bullets with `rich_body` still display via `rich_body?` in read views. Rendered rich text uses `.rich-text-content` alongside Lexxy's `.lexxy-content`. **Project tags** use `bullet_projects` → `projects`; `Projectable` syncs join rows from `#` attachments in `body` on save (pills inline via `projects/_attachable`). **Person tags** use `bullet_people` → `people`; `Personable` syncs from `@` attachments in `body`. The unified composer (`bullets/_bulletable_form.html.erb`) is opened via **Add bullet**; type (Task / Note / Event) is chosen with a select (locked on edit). Note-only mood picker toggles when Note is selected and submits `bulletable_attributes[:mood]` via `BulletContentFinalizer` on save. Attachment hydration for the Lexxy editor runs view-side via `BulletEditorContentHelper#hydrate_editor_content` (`app/helpers/bullet_editor_content_helper.rb`), called from `_form_fields.html.erb`; the model's `Projectable#editor_content_for_form` returns raw HTML. Paste/drop/file-picker on the inline editor are intercepted (`lexxy:file-accept`) and routed to direct attachments. **Bucket membership**: `Bullet` optionally `belongs_to :bucket` for **Collection** and **TimeSpread** only. **`Collectable`** sets or clears `bullets.bucket_id`; bulk collect picks a collection via `POST /bullets/collect` with `bucket_id`. Other intents (`Poppable`, etc.) update `pops_on`, `bucket`, and migration state without type conversion.

### Bullet Status
`Bullet` has a `pinned` boolean column (`default: false, null: false`). Archive state is **not** a column — it lives in a separate polymorphic `Archive` entity (see **Archive entity** below). There is no `status` enum. `Pinnable` adds a `pinned` scope and `pin!` / `unpin!` helpers (used by bullets and buckets; no pin count limit). `Bullet::Archivable` (namespaced concern) adds `archived` / `active` scopes backed by the `archives` join. The `timeline` scope returns all bullets (`all`) — pinned and archived bullets remain visible in the timeline and are distinguished by icons in the bullet partial.

`Bullet` tracks **`migrated_at`** (`datetime`, nullable) and **`last_migration`** (json, default `{}`): set by **`Migratable#stamp_migration!`** when the user schedules (pop with date change), collects, completes, or archives. `migrated?` drives the `›` marker on bullet rows. Full history lives in **`activities.metadata`** (same payload shape). Project/person tags do **not** stamp migration.

### Archive entity
Archiving (`Bullet` or `Bucket`) is modelled as a row in **`archives`** (`archivable_type` / `archivable_id` polymorphic, `user_id`, timestamps), mirroring `PinnedEntity`. A unique index guarantees at most one `Archive` per subject. `Archive#created_at` replaces the old `archives_on` column; `Archive#user_id` records who archived.

State access is split into two **namespaced** concerns (no shared module — Bullet and Bucket diverge too much for one concern):

- **`Bullet::Archivable`** — `has_one :archive`, `archived` / `active` / `expired_archived` scopes, `archive!` (writes `Archive` row + `stamp_migration!(kind: "discarded")` → `archived` activity), `unarchive!` (destroys row + `unarchived` activity).
- **`Bucket::Archivable`** — same shape but `archive!` / `unarchive!` record `archived` / `unarchived` activities directly with `bucketable_type` metadata; also calls `reindex` so `Searchable` cache stays in sync (the bucket row is not `update!`-ed, so `after_update_commit :update_in_search_index` does not fire on its own).

Because archive/unarchive is now an INSERT/DELETE into `archives` (not an `update!` of the subject), **`Bucket#after_update :record_updated_activity` no longer double-logs** on archive transitions. Activity is recorded exactly once, inside the transaction. `archives_on` is exposed as a shim (`archive&.created_at&.to_date`) for views and tests.

### Activity
`Activity` is a polymorphic audit log: **`subject`** (`Bullet` or `Bucket`), **`action`** (string), **`metadata`** (json), **`user_id`**. Recording goes through **`ActivityTrackable#record_activity!`** on subjects. Bullet actions: `updated`, `collected`, `popped`, `archived`, `unarchived`, `completed`, `uncompleted`, `project_tagged` / `project_untagged`, `person_tagged` / `person_untagged`. Bucket actions: `created`, `updated`, `pinned`, `unpinned`, `archived`, `unarchived`. Migration intents write bullet activities with migration payload in `metadata`. Pin/unpin on bullets does **not** record activity. **`GET /activities`** lists the user's feed; filter with `?subject_type=Bullet&subject_id=` (or `Bucket`).

### Recurrency
`Recurrency` tracks repeating actions per user (`belongs_to :user`). One mark per calendar day via **`RecurrencyCompletion`** (`recurrency_id`, `date`, unique index). Not a bullet — no bucket, migration, or sweep. Identity uses **`Colourable`** / **`Iconable`** (`colour`, `icon` columns) like collections.

**Schedule** (`schedule` json): `daily`, `weekdays`, or `custom` (`days` = Ruby `wday` 0–6). **Lifecycle:** `active_from` / `active_to` (nullable); set `active_to` to retire without deleting history. **Destroy** is blocked when completions exist (`dependent: :restrict_with_error`).

**`RecurrencyTracker`** (plain object) loads recurrencies + completions for a date range; exposes `completed?`, `stats` (streak, best streak, total, period %).

**UI:** `GET /recurrencies` (CRUD + show with heatmap/month grid; create/edit form includes colour + icon pickers like collections). Daylog: compact clickable icon chips in the page header (`recurrencies/_header_chips`). Monthly spread: dedicated recurrency column aligned per day via `monthly-bucket--day-band` (recurrency slot + date row share one row); unplanned in the third column. Mobile tabs: days vs unplanned. Toggle: each chip is a `form_with` (`recurrencies/_toggle`) posting to `POST`/`DELETE /recurrencies/:id/completion` with `date` + `dom_key`; turbo-stream replaces only that form. Home rail links to `/recurrencies`.

### Review
**`GET /review`** (`ReviewsController#show`, `?from=YYYY-MM-DD&to=YYYY-MM-DD`, defaults to the last 7 days through today) lists timeline bullets for the period: `Bullet.in_review` = `bucket_id` nil, not archived, `pops_on` in range — all types. Bucket members are excluded (collect = migration off timeline). Migration state is **not** a review filter. Monthly bucket review is a separate future strategy.

**Review UI:** Desktop (`show.html.erb`, ≥800px) is a 3-column workspace in `review.css`: collections (left, drop → collect via `collect-drop` Stimulus), inbox (center, draggable bullets + bulk-menu), 7-day week strip anchored at `review_to` (right, drop → pop via `pop-drop` with `reviewDrop`). Mobile web (`show.html+mobile.erb`) shows inbox only with per-row actions (`review-row`: tomorrow pop, collect picker sheet, complete/archive) plus bulk-menu; native swipes are out of scope. Drop handlers POST with `X-Requested-With: review-pop-drop` / `review-collect-drop`; controllers return `head :no_content` so the client removes the bullet frame from the inbox.

### Daily log and `pops_on`
Bullets use `pops_on` (`date`) as the primary day bucket: which daily log page the bullet appears on. `Bullet.pops_on_date(date)` matches bullets for that calendar day per the model rules. The daily log is at `/daylog` (today) or `/daylog?date=YYYY-MM-DD`; pass `date:` to `daylog_path` when linking to another day.

### Monthly log spread
`MonthlyBucket` is a `bucketable` type (thin model + `Bucketable` + `Periodable`). The spread period lives on the monthly bucket itself via **`Periodable`** (`period_from`, `period_to`, `period_days`, `period_ranges_correct`). `period_from` is snapped to the 1st of the month; each user may have at most one spread per calendar month (`user_id` + `period_from` unique). Spreads must cover a full calendar month (`period_from` through `period_to.end_of_month`). **`MonthlyBucket.current(user)`** returns the spread for the current calendar month (`find_by(period_from: …)`), or `nil` (no auto-create). **`covers_date?(date)`** checks whether a date falls in that spread's month. **`MonthlyBucket`** may belong to a **`FutureBucket`** (a user may have multiple future logs over time). Nested under **`GET /future`** in routes; monthly spreads live at **`/future/monthly_buckets/:id`**. Shortcut **`GET /monthly_bucket`** still opens the current calendar month. Left area: two-column calendar (`recurrency` slot per day aligned with matching date row) plus bullets; right column: unplanned (`pops_on` nil). `pops_on` still places bullets on the daily log when set.

### Organizing from the timeline
Select bullets via row checkboxes; the sticky **`_bulk_menu`** (styled in `bulk-menu.css`, driven by `bulk-menu` Stimulus on the page wrapper) keeps selection in **`idListValue`** and syncs a comma-separated `bullet_ids` CSV into every `data-bulk-menu-target="idList"` hidden field.

**Direct intents (no UI fetch):** **pin**, **archive** — `POST`/`DELETE` with `turbo_stream` from menu forms.

**UI fetch then intent:** **pop** and **collect** — `openPopsPicker` / `openCollectsPicker` set frame `src` with `bullet_ids` from `idListValue`, then `showPopover()` (lazy turbo-frame + popover, like pinned footer); picker POST/search forms use `data-bulk-menu-target="idList"` (synced on `idListTargetConnected` and `idListValueChanged`). Collect picker search reloads the `collects_picker_frame` via GET with `q`. Menu embeds search via `turbo-frame#menu_search` (`GET /search`, turbo-stream for live input); menu shell is `GET /menu`. Lexxy `#` / `@` suggestions use `filter`.

**Pop intent:** `POST /bullets/pop` with `pops_on` (`DELETE` to restore previous day). **Collect intent:** `POST /bullets/collect` with `bucket_id` (`DELETE` uncollects the selection). **Postpone** on the daylog is `POST /bullets/pop` with `pops_on` = viewing day + 1. Pin/Unpin buttons hide when the selection includes a pinned or unpinned bullet respectively (`data-pinned` on checkboxes). Activity records `popped` and `collected`; reports infer moves from `pops_on` changes. Project/person tag changes from Lexxy attachments record `project_tagged` / `project_untagged` and `person_tagged` / `person_untagged`. Responses use Turbo Streams where applicable, with HTML fallbacks.

`Collectable` and `Poppable` are intent-focused concerns; they do not force bullet type conversion.

### Sweep Rules
`CleanSoftDeletedRecordsJob` runs daily and purges expired archived records:

- **`Bullet.expired_archived.destroy_all`** — hard-deletes archived bullets after `Bullet::Archivable::RETENTION_DAYS` (30 days); pinned bullets are excluded
- **`Bucket.expired_archived.destroy_all`** — hard-deletes archived buckets after `Bucket::Archivable::RETENTION_DAYS` (30 days); pinned buckets are excluded; for `Collection` buckets, destroys the `Collection` row; collected bullets are nullified (`bucket_id` nil)

Bullet auto-archive (grace window, completed → archive row) is **not implemented yet** — the job no longer calls the missing `Bullet.auto_archivable` scope.

Planned bullet recycling (not yet in code):

- completed bullets remain recyclable through their archive row (set by future auto-archive logic)
- bullets are auto-archived when due or still untriaged after a grace window
- pinned bullets are excluded from auto-archive

### Analog BuJo Alignment
The architecture is intentionally closer to analog Bullet Journal behavior:

- **Rapid logging** uses one **Add bullet** composer with a type select (Task / Note / Event); inline `body` by default, Note's rich_body available inline in the Note composer
- **Daily focus** is explicit (`/daylog` and dated daylog paths show the daily log)
- **Migration over rewrite** happens where needed by editing or changing bullet type
- **Deferred decisions** are supported by moving `pops_on` forward (postpone) or tagging a project
- **Separation of concerns** mirrors BuJo pages: today/timeline, archived, pinned

### Projects (tags)
`Project` is a first-class model (`belongs_to :user`) with `name`, `colour`, `icon`, and `pinned` (`Colourable`, `Iconable`, `Pinnable`, `ActionText::Attachable`). Bullets link via `bullet_projects` (many-to-many; a bullet may have several project tags). `GET /projects/:id` lists bullets joined through `bullet_projects`. Project show composer passes `default_project_id` so new bullets hydrate with that tag in the editor. Pin/unpin uses `POST`/`DELETE` on `projects/pin`. `Person` mirrors the same pin/unpin pattern via `people/pin` on the person show page.

### Buckets and memberships
`Bucket` belongs to a user and uses `delegated_type :bucketable` (`Collection`, `FutureBucket`, `MonthlyBucket`). `MonthlyBucket` includes **`Periodable`** for time restrictions (`period_from` / `period_to`). Each bullet has **zero or one** bucket via `bullets.bucket_id` for collection/bucket membership. `Collection` rows do not store `user_id`; ownership is the bucket’s `user_id`, with `creation_user_id` on the bucketable for attribution where needed. Bucket **identity** (`name`, `colour`, `icon`) is stored on `buckets` (`name` required; `colour` / `icon` optional via `Colourable` and `Iconable`; no auto-assign). Collection bucket names are unique per user. `Collection` is a thin delegated type (no identity columns); it delegates `name`, `colour`, `icon`, and colour CSS helpers to `bucket` for display. Create forms pass identity fields on the bucketable param object; controllers persist them on the bucket row. The home hub is at `GET /home` (linked from the app header). **Streams** (saved filtered views) were removed; use projects, collections, and timeline filters instead.

**Collection archive:** all bucket types are archivable (`Bucket#archive!` / `#unarchive!` via `Bucket::Archivable`). `DELETE /collections/:id` soft-archives the bucket by inserting an `Archive` row; archived collections are hidden from home, review collect panel, and collect picker (`user_collections` filters via `Bucket.active`). Collect into an archived bucket is rejected (`Collectable` uses the `.active` scope, surfacing 404). Activity records `archived` / `unarchived` on the bucket. Purge after retention is handled by `CleanSoftDeletedRecordsJob` (see Sweep Rules).

### Pinned workspace
Desktop footer docks live in [`shared/_footer.html.erb`](app/views/shared/_footer.html.erb) (`#pinned_buckets_footer`, `#pinned_bullets_dock`) but are not mounted in the default layout while navigation is in flux. Pin/unpin Turbo Streams still target those frame ids when present. Mobile uses the bottom tab bar (`shared/_mobile_tab_bar`) and **`GET /pinned`** workspace (`pinned/index.html+mobile.erb`) for pinned bullets, pinned projects, pinned people, and pinned bucket groups (collections/timespreads). Lazy popover lists still load via [`pinned#index`](app/controllers/pinned_controller.rb) (`Turbo-Frame: pinned_bullets`) or [`buckets#show`](app/controllers/buckets_controller.rb) for footer bucket frames.

### Turbo Streams
Mutating bullet actions (`create`, `update`, `destroy`, and bullet sub-resources) respond to `format.turbo_stream` for inline updates where applicable. HTML fallback redirects are provided. Bulk intents use the shared `_bulk_menu` forms; row checkboxes are unstyled (native inputs).

### Routes

```
root                                         → daylogs#show (today)

# Auth
resource :session                            → sessions#new/create/show/destroy
resource :session/code                       → sessions/codes#new/create

# Logs (?date=YYYY-MM-DD for a specific day)
GET    /daylog                               → daylogs#show
GET    /monthly_bucket                       → monthly_buckets#current (current spread or empty)
GET    /future                               → futures#show
POST   /future/months                        → futures#months
GET    /future/monthly_buckets/:id           → monthly_buckets#show
GET    /future/monthly_buckets/new           → monthly_buckets#new
POST   /future/monthly_buckets               → monthly_buckets#create
GET    /future/monthly_buckets/:monthly_bucket_id/bullets/new → monthly_buckets/bullets#new
POST   /future/monthly_buckets/:monthly_bucket_id/bullets     → monthly_buckets/bullets#create

# Bullets CRUD (no index — daily log is /daylog)
GET    /bullets/:id                          → bullets#show
GET    /bullets/new                          → bullets#new
POST   /bullets                              → bullets#create
GET    /bullets/:id/edit                     → bullets#edit
PATCH  /bullets/:id                          → bullets#update
DELETE /bullets/:id                          → bullets#destroy

# Bullet bulk intents (collection; `bullet_ids` comma-separated)
POST   /bullets/pin                          → bullets/pins#create
DELETE /bullets/pin                          → bullets/pins#destroy
POST   /bullets/archive                      → bullets/archives#create
DELETE /bullets/archive                      → bullets/archives#destroy
POST   /bullets/collect                      → bullets/collects#create (collect into collection; `bucket_id`)
GET    /bullets/collect/new                  → bullets/collects#new
DELETE /bullets/collect                      → bullets/collects#destroy (uncollect)
POST   /bullets/pop                          → bullets/pops#create
DELETE /bullets/pop                          → bullets/pops#destroy
POST   /bullets/:bullet_id/complete          → bullets/completes#create
DELETE /bullets/:bullet_id/complete          → bullets/completes#destroy
POST   /bullets/publish                      → bullets/publishes#create
DELETE /bullets/publish                      → bullets/publishes#destroy
GET    /bullets/export                       → bullets/exports#show

# Search & menu
GET    /search                               → searches#show (?q=; turbo-stream updates menu_search frame)
GET    /menu                                 → menu#show (?q= pre-fills search field)

# Home, buckets
GET    /home                                 → home#show (navigation hub)
PATCH  /home/sections/:id                    → home/sections#update (persist section open/close state)
GET    /buckets/:id                          → buckets#show (footer popover bullet list)
POST   /buckets/pin                          → buckets/pins#create
DELETE /buckets/pin                          → buckets/pins#destroy

# Tags
GET    /projects/suggestions                 → projects/suggestions#index (Lexxy `#` prompt items)
POST   /projects/pin                         → projects/pins#create
DELETE /projects/pin                         → projects/pins#destroy
resources :projects, only: %i[index new create show destroy]
GET    /people/suggestions                   → people/suggestions#index
POST   /people/pin                           → people/pins#create
DELETE /people/pin                           → people/pins#destroy
resources :people, only: %i[index new create show destroy]
resources :collections, only: %i[index new create show destroy]

# Recurrency
resources :recurrencies do
  resource :completion, only: %i[create destroy], module: :recurrencies
end

# Views
GET    /review                               → reviews#show (?from= &to=YYYY-MM-DD)
GET    /activities                           → activities#index (?subject_type= &subject_id= optional)
resources :pinned, only: :index
resources :archived, only: :index
resources :published, param: :code

# Health check
GET    /up                                   → rails/health#show
```

### Database Strategy
SQLite for all environments. Production uses separate SQLite databases for primary data, Solid Cache, Solid Queue, and Solid Cable — no Redis dependency.

### Asset Pipeline
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
| `button.css` | `button--primary`, `button--secondary`, `button--tertiary`, `button--icon`, `button--circle`, `button--danger` (with `button--secondary`) | Shared chrome for links and `<button>`; hover/active in `button.css` |
| `utilities.css` | `utilities--sr-only`, `utilities--line-clamp-1`, `utilities--text-sm` | Small cross-page helpers only; prefer component/layout classes when possible |
| `layout.css` | `layout--page`, `layout--column`, `layout--header`, `layout--header-actions`, `layout--list`, `layout--list-item`, `layout--main`, `header`, `footer`, `footer--dock` | Page structure and app shell chrome (`shared/_header`, `shared/_footer`; daylog and bucket pages use `layout--page`) |
| `bucket.css` | `bucket--list`, `bucket--list-item-link`, `bucket--list-item-marker`, … | Bucket list chrome and item styling (pair with `layout--list` / `layout--list-item`) |

Styles are layered in `application.css`: `reset` → `variables` → `base` → `layout` → `utilities` → `components`. Tokens live in `variables.css` (`--color-*`, `--shadow-subtle` / `--shadow-base` / `--shadow-strong`, `--z-dialog-backdrop` → `--z-dropdown` → `--z-dialog` → `--z-toast`). Element defaults and keyboard focus rings live in `base.css`; `_reset.css` is browser normalization only.

**CSS: pick the closest existing variable — never add new ones.** When a hardcoded CSS value (font-size, border-radius, font-weight, opacity, icon size, etc.) doesn't exactly match an existing variable, map it to the nearest one from `variables.css` rather than creating a new variable. The variable set is intentionally small and should stay that way. A 1–2px difference is acceptable — consistency across the system matters more than pixel-perfect fidelity to the original arbitrary value. Do not add `line-height` or `letter-spacing` declarations — the reset handles base values.

### Turbo

**Prefer `<turbo-frame>` tags in HTML/ERB over ERB helper alternatives.** Use the raw `<turbo-frame id="...">` element directly rather than `turbo_frame_tag` helpers when writing views. This keeps templates explicit, readable, and framework-agnostic. Use `data-turbo-*` attributes directly on elements rather than wrapping helpers where possible.

**Always consult the Turbo reference** (https://turbo.hotwired.dev/reference/drive) and the Rails guides when implementing Turbo features. Turbo events (`turbo:submit-end`, `turbo:render`, etc.) have specific ordering and guarantees — check docs instead of guessing.

### Testing Policy

**Tests are only edited when the logic they cover has intentionally changed.** A failing test is a signal to fix the code, not the test. The only valid reasons to modify an existing test are:

- The behaviour the test covers was deliberately changed (e.g. a renamed param, a new model API)
- The test itself was wrong and never reflected real behaviour

**Never adjust a test simply to make it pass.** Weakening assertions, broadening matchers, or skipping edge cases to silence a failure hides real regressions and potential UX breakage. If a test is failing and the production code looks correct, investigate why — don't paper over it.

### Ruby LSP

**Use Ruby LSP extensively when working with Ruby on Rails code.** Before editing or creating Ruby files, use LSP tools to:
- Look up method signatures, hover docs, and type information
- Navigate to definitions (`go to definition`) rather than grepping for them
- Find all references before renaming or removing a method/class
- Let LSP diagnostics surface errors before running tests
- Prefer LSP-informed edits over grep-and-replace for refactoring Ruby

### Reference Projects

Basecamp open-source Rails apps are good references for Rails patterns, Turbo usage, and Stimulus conventions:

- **Fizzy** (github.com/basecamp/fizzy) — Rails patterns, nested routes via `scope module:`
- **Campfire** (github.com/basecamp/campfire) — real-time features, Turbo Streams
- **Writebook** (github.com/basecamp/writebook) — content publishing, form patterns

Consult these when implementing non-trivial features to see idiomatic Rails/Turbo/Stimulus usage.
