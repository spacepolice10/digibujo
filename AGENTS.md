# AGENTS.md

This file contains agent workflow, architecture, and implementation guidance for this repository.

## Common Commands

### Development
- `bin/setup` — install deps, prepare DB, start server (`--reset` to reset DB, `--skip-server` to skip)
- `bin/dev` — start dev server
- `server` — Nix convenience: runs Rails server with tspin for colored output
- `logs` — Nix convenience: tails development.log with tspin

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

## Architecture

### Authentication
Custom session-based auth built with an `Authentication` concern (not Devise). Uses `has_secure_password`, signed httponly cookies, and `Current.user` via `ActiveSupport::CurrentAttributes`. Controllers opt out of auth with `allow_unauthenticated_access`. Rate limiting is applied to login and password reset endpoints.

### Delegated Type Pattern (Bullets)
`Bullet` uses `delegated_type :bulletable` for polymorphism. The `bullets` table holds `bulletable_type`/`bulletable_id`. Implemented bulletable types:

| Type    | Concerns                       | Notes                              |
|---------|--------------------------------|------------------------------------|
| `Task`  | `Bulletable`                   | Completable + temporal; composer leading `-` |
| `Note`  | `Bulletable`                   | Long-form/reference entry; no prefix (plain line) |
| `Event` | `Bulletable`                   | Temporal (not completable); composer leading `>` |

Bullets have rich text `content` via Action Text (Trix). **Organization:** `Bullet` **optionally** `belongs_to :bucket` (`bullets.bucket_id` → `buckets`). A bullet is in **at most one** bucket (either a project bucket or a collection bucket), not several. There is **no** `bullets.project_id` and no virtual `project_id` on `Bullet`. A `Bucket` is a `delegated_type :bucketable` whose types include `Project` and `Collection` (each owns exactly one `Bucket`). The composer posts **`bucket_id`** for the project picker (or prefills when composing from a project/collection page). **Collect** and **schedule** intents accept **`bucket_id`**. **Destroying** a bucket **nullifies** `bullets.bucket_id` for linked bullets (`dependent: :nullify`). Intent methods in concerns (`Collectable#collect!`, `Schedulable#schedule!`, etc.) update organization metadata (`triaged_at`, `scheduled_on`, `bucket`) without forcing bullet type conversion. To add a new bulletable type: create the model, `include Bulletable`, implement `form_fields`, and register it in `Bullet`'s `delegated_type` declaration.

### Bullet Status
`Bullet` has two independent boolean columns: `pinned` and `archived` (both `default: false, null: false`). There is no `status` enum. `Pinnable` adds a `pinned` scope and enforces a limit of 10 pinned bullets per user. `Archivable` adds an `archived` scope. The `timeline` scope returns all bullets (`all`) — pinned and archived bullets remain visible in the timeline and are distinguished by icons in the bullet partial.

`Bullet` also tracks `triaged_at` (`datetime`): `nil` means no organizing intent has stamped disposition yet; present means the user applied an action (e.g. collect or schedule) that sets this timestamp.

### Scheduling and day buckets
Bullets use `scheduled_on` (`date`) as the primary day bucket (replacing the older `pops_on` / separate date fields). `Bullet.scheduled_on_date(date)` matches bullets for that calendar day per the model rules. The timeline at `/bullets` uses this scope for the selected day (`?date=`).

### Organizing from the timeline
From each bullet row (⋯ menu), users can **collect** (`POST /bullets/:bullet_id/collect` with `bucket_id`), **schedule** (`POST /bullets/:bullet_id/schedule` with `bucket_id`), **postpone** (`POST /bullets/:bullet_id/postpone`), and **archive** (`PATCH /bullets/:bullet_id/archive`). Responses use Turbo Streams where applicable, with HTML fallbacks (typically redirect to `/bullets`).

`Collectable` and `Schedulable` are intent-focused concerns; they do not force bullet type conversion.

### Sweep Rules
`SweepCardsJob` (name unchanged) operates on `Bullet` and enforces recycling rules:

- completed bullets remain recyclable through `archives_on` (set by `Completable#complete!`)
- bullets are auto-archived when due (`archives_on <= today`) or still untriaged after a grace window
- pinned bullets are excluded from auto-archive and deletion
- archived bullets are hard-deleted only after a retention period, and pinned bullets are excluded there too

### Analog BuJo Alignment
The architecture is intentionally closer to analog Bullet Journal behavior:

- **Rapid logging markers** in the composer: leading `-` switches to Task, leading `>` to Event (stripped only when the type changes; plain line is Note)
- **Daily focus** is explicit (`/bullets` shows the scheduled timeline for the selected day)
- **Migration over rewrite** happens where needed by editing or changing bullet type
- **Deferred decisions** are supported by moving `scheduled_on` forward (postpone) or collecting/scheduling into a project or date
- **Separation of concerns** mirrors BuJo pages: today/timeline, archived, pinned

### Buckets and memberships
`Bucket` belongs to a user and uses `delegated_type :bucketable` (`Project`, `Collection`). Each bullet has **zero or one** bucket via `bullets.bucket_id` (no `bullet_buckets` join table). `Project` / `Collection` rows do not store `user_id`; ownership is the bucket’s `user_id`, with `creation_user_id` on the bucketable for attribution where needed. Bucket **identity** (`name`, `colour`, `icon`) is stored on `buckets` (`name` required; `colour` / `icon` optional via `Colourable` and `Iconable`; no auto-assign). Collection bucket names are unique per user; project names may repeat. `Project` and `Collection` are thin delegated types (no identity columns); they delegate `name`, `colour`, `icon`, and colour CSS helpers to `bucket` for display. Create forms pass identity fields on the bucketable param object; controllers persist them on the bucket row. The index hub is at `GET /buckets` (linked from the app header). **Streams** (saved filtered views) were removed; use projects, collections, and timeline filters instead.

### Turbo Streams
Mutating bullet actions (`create`, `update`, `destroy`, and bullet sub-resources) respond to `format.turbo_stream` for inline updates where applicable. HTML fallback redirects are provided.

### Routes

```
root                                         → bullets#index

# Auth
resource :session                            → sessions#new/create/show/destroy
resource :session/code                       → sessions/codes#new/create

# Bullets (dynamic fields + JSON contexts under scoped module)
GET    /bullets/fields/:id                   → bullets/fields#show (id=task|note|event)
GET    /bullets/contexts                     → bullets/contexts#index (JSON)

# Bullets CRUD
GET    /bullets                              → bullets#index (today timeline)
GET    /bullets/:id                          → bullets#show
GET    /bullets/new                          → bullets#new
POST   /bullets                              → bullets#create
GET    /bullets/:id/edit                     → bullets#edit
PATCH  /bullets/:id                          → bullets#update
DELETE /bullets/:id                          → bullets#destroy

# Bullet sub-resources (Turbo Stream responses)
PATCH  /bullets/:bullet_id/pin               → bullets/pins#update
PATCH  /bullets/:bullet_id/archive           → bullets/archives#update
POST   /bullets/:bullet_id/postpone          → bullets/postpones#create
POST   /bullets/:bullet_id/collect           → bullets/collects#create
POST   /bullets/:bullet_id/schedule          → bullets/schedules#create
POST   /bullets/:bullet_id/complete          → bullets/completes#create
DELETE /bullets/:bullet_id/complete          → bullets/completes#destroy
PATCH  /bullets/:bullet_id/publish           → bullets/publishes#update

# Search
resource :search, only: :show

# Buckets, projects, collections
GET    /buckets                              → buckets#show (sidebar shell; turbo-frame target)
GET    /projects                             → projects#index (HTML + JSON picker; JSON includes `bucket_id`)
GET    /projects/new                         → projects#new
POST   /projects                             → projects#create (creates project + bucket; JSON returns `bucket_id`)
GET    /projects/:id                         → projects#show
DELETE /projects/:id                         → projects#destroy
GET    /collections                          → collections#index
GET    /collections/new                      → collections#new
POST   /collections                          → collections#create
GET    /collections/:id                      → collections#show
DELETE /collections/:id                      → collections#destroy

# Other pages
resource  :history, only: :show
GET    /activities                           → activities#index (?bullet_id= optional)
resource  :calendar, only: :show
resources :pinned, only: :index
resources :archived, only: :index
resources :published, param: :code
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
- Nix flake for reproducible dev environment (Ruby, Node 24, Docker/Colima)
- Kamal for deployment with Thruster for HTTP acceleration
- Solid Queue runs in-process with Puma (`SOLID_QUEUE_IN_PUMA=true`)

### Variables

**Prefer variables over arbitrary data.** Instead of hardcoding values (strings, numbers, colors, URLs, etc.) directly in views, stylesheets, or configs, extract them into named variables:
- CSS: use CSS custom properties (`--variable-name`) defined in a single `:root` block
- Ruby/ERB: use constants, model attributes, or controller-assigned `@variables` — never inline magic values
- Configuration: use Rails credentials, environment variables, or initializers — never inline secrets or environment-specific values

**CSS class naming follows a file-scoped convention.** The first segment of a class name matches the stylesheet filename it lives in (the "block"). Everything after `--` identifies a specific nested element within that block. For example, classes in `date-picker.css` are named `date-picker` (the block), `date-picker--segments-picker` (a nested container), `date-picker--segments-button` (a nested element). Never use a prefix that doesn't correspond to the file it's defined in.

**CSS: pick the closest existing variable — never add new ones.** When a hardcoded CSS value (font-size, border-radius, font-weight, opacity, icon size, etc.) doesn't exactly match an existing variable, map it to the nearest one from `variables.css` rather than creating a new variable. The variable set is intentionally small and should stay that way. A 1–2px difference is acceptable — consistency across the system matters more than pixel-perfect fidelity to the original arbitrary value. Do not add `line-height` or `letter-spacing` declarations — the reset handles base values.

### Turbo

**Prefer `<turbo-frame>` tags in HTML/ERB over ERB helper alternatives.** Use the raw `<turbo-frame id="...">` element directly rather than `turbo_frame_tag` helpers when writing views. This keeps templates explicit, readable, and framework-agnostic. Use `data-turbo-*` attributes directly on elements rather than wrapping helpers where possible.

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
