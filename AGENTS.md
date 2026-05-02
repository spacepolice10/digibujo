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
| `Task`  | `Bulletable`                   | Completable + temporal; uses marker `•` |
| `Note`  | `Bulletable`                   | Long-form/reference entry; uses marker `-` |
| `Event` | `Bulletable`                   | Temporal (not completable); uses marker `○` |

Bullets have rich text `content` via Action Text (Trix). Optional `belongs_to :project` groups work under user-owned `Project` records (replacing the old collections/tags flow). Triage intent methods live in concerns (`Collectable#collect!`, `Schedulable#schedule!`) and update organization metadata without forcing type conversion. To add a new bulletable type: create the model, `include Bulletable`, implement `form_fields`, and register it in `Bullet`'s `delegated_type` declaration.

### Bullet Status
`Bullet` has two independent boolean columns: `pinned` and `archived` (both `default: false, null: false`). There is no `status` enum. `Pinnable` adds a `pinned` scope and enforces a limit of 10 pinned bullets per user. `Archivable` adds an `archived` scope. The `timeline` scope returns all bullets (`all`) — pinned and archived bullets remain visible in the timeline and are distinguished by icons in the bullet partial.

`Bullet` also tracks `triaged_at` (`datetime`): `nil` means not intentionally triaged yet; present means the user has processed it via triage actions such as collect or schedule.

### Scheduling and triage eligibility
Bullets use `scheduled_on` (`date`) as the primary day bucket (replacing the older `pops_on` / separate date fields). `Bullet.scheduled_on_date(date)` matches bullets explicitly scheduled on that day or created that day when `scheduled_on` is nil. `Bullet.triage_on_date(date)` further narrows to bullets that still need triage for that day (not yet triaged with a `triaged_at` falling on that calendar day). `TriageController#show` lists non-archived bullets from `triage_on_date` for the selected date (default today).

### Triage Workflow
Triage is bullet-first (`/triage`) with an optional `?date=` query for day navigation. During triage, each bullet can be:

- **Collect** → `Triage::CollectsController` calls `bullet.collect!(project_id:, project_name:)` to attach a project and stamp `triaged_at`
- **Schedule** → `Triage::SchedulesController` calls `bullet.schedule!(scheduled_on:)` to set the scheduled day and stamp `triaged_at`
- **Postpone** → `Triage::PostponesController` moves `scheduled_on` to the next day (relative to the triage date) and stamps `triaged_at`
- **Archive** → `Triage::ArchivesController` sets `archived: true`

`Collectable` and `Schedulable` are intent-focused concerns. They support triage without coupling it to bullet type switching.

### Sweep Rules
`SweepCardsJob` (name unchanged) operates on `Bullet` and enforces recycling rules:

- completed bullets remain recyclable through `archives_on` (set by `Completable#complete!`)
- bullets are auto-archived when due (`archives_on <= today`) or still untriaged after a grace window
- pinned bullets are excluded from auto-archive and deletion
- archived bullets are hard-deleted only after a retention period, and pinned bullets are excluded there too

### Analog BuJo Alignment
The architecture is intentionally closer to analog Bullet Journal behavior:

- **Rapid logging markers** are first-class (`•` Task, `-` Note, `○` Event)
- **Daily focus** is explicit (`/bullets` shows today’s scheduled timeline; triage uses `scheduled_on` per day)
- **Migration over rewrite** happens in triage by converting bullet type in place where needed
- **Deferred decisions** are supported by moving `scheduled_on` forward (postpone) or collecting/scheduling into a project or date
- **Separation of concerns** mirrors BuJo pages: today/timeline, triage, archived, pinned

### Streams
`Stream` is a saved filtered view. It stores filter fields (`bulletable_type`, `sorted_by`, `date_from`, `date_to`, `projects`, plus display `icon`/`colour`) via `store_accessor :fields`. `Stream#bullets` builds a scoped query against `user.bullets`. Streams are user-owned and uniquely named.

### Playlists
Playlists reference bullets through the `playlist_cards` join model (`PlaylistCard`), which uses `bullet_id` foreign keys. Nested routes use `/playlists/:playlist_id/bullets` for add/remove.

### Turbo Streams
All mutating actions (`create`, `update`, `destroy`) in bullets and triage sub-controllers respond to `format.turbo_stream` for inline updates without page reloads. HTML fallback redirects are always provided.

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
POST   /bullets/:bullet_id/complete          → bullets/completes#create
DELETE /bullets/:bullet_id/complete          → bullets/completes#destroy
PATCH  /bullets/:bullet_id/publish           → bullets/publishes#update
GET    /bullets/:bullet_id/playlist_picker   → bullets/playlist_pickers#show

# Search
resource :search, only: :show

# Triage (optional ?date=ISO8601 on GET)
GET    /triage                               → triage#show
POST   /triage/bullets/:bullet_id/collect    → triage/collects#create
POST   /triage/bullets/:bullet_id/schedule   → triage/schedules#create
POST   /triage/bullets/:bullet_id/postpone   → triage/postpones#create
POST   /triage/bullets/:bullet_id/archive    → triage/archives#create

# Playlists
resources :playlists, only: %i[index show create destroy]
  (+ nested bullets POST/DELETE, reorder PATCH)

# Projects & streams
GET    /indexing                             → streams#index (alias)
GET    /projects                             → projects#index (JSON suggestions)
resources :projects, only: %i[show destroy]
resources :streams                           → streams CRUD

# Other pages
resource  :history, only: :show
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
