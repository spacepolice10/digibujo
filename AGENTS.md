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

### Delegated Type Pattern (Cards)
`Card` uses `delegated_type :cardable` for polymorphism. The `cards` table holds `cardable_type`/`cardable_id`. Implemented cardable types:

| Type    | Concerns                       | Notes                              |
|---------|--------------------------------|------------------------------------|
| `Draft` | `Cardable`, `Schedulable`, `Collectable` | Entry point for all captures; promoted to Task or Note during triage |
| `Task`  | `Cardable`                     | Completable, temporal; has `done`/`done_at` fields |
| `Note`  | `Cardable`                     | Tagged permanent cards             |

Cards have rich text `content` via Action Text (Trix). To add a new cardable type: create the model, `include Cardable`, implement `form_fields`, and register in `Card`'s `delegated_type` declaration.

### Card Status
`Card` has two independent boolean columns: `pinned` and `archived` (both `default: false, null: false`). There is no `status` enum. `Pinnable` adds a `pinned` scope and enforces a limit of 10 pinned cards per user. `Archivable` adds an `archived` scope. The `timeline` scope returns all cards (`all`) — pinned and archived cards remain visible in the Timeline and are distinguished by icons in the card partial.

### Pop Mechanism
Cards have a `pops_on` date column. A card is "popped" when `pops_on <= Date.today`. Popped drafts surface in the Drafts triage view. `Cards::PopsController#update` toggles/sets/clears `pops_on`. Drafts can also be postponed (set a future `pops_on`) via `Drafts::PostponesController`.

### Draft Promotion (Triage Workflow)
Drafts are the raw capture state. During triage (`/drafts`), each draft can be:
- **Scheduled** → `Drafts::SchedulesController` calls `cardable.schedule_as_task!` (promotes via `Schedulable` → `Promotable`)
- **Collected** → `Drafts::CollectsController` calls `cardable.collect_as_note!(tag_names:)` (promotes via `Collectable` → `Promotable`)
- **Postponed** → `Drafts::PostponesController` sets a future `pops_on`
- **Removed** → `Drafts::RemovesController` destroys the card

`Promotable#promote_to!` wraps the swap in a transaction: saves the new cardable, updates `card.cardable`, optionally applies tags, then destroys the old cardable.

### Streams
`Stream` is a saved filtered view. It stores filter fields (`cardable_type`, `sorted_by`, `date_from`, `date_to`, `tag_names`) via `store_accessor :fields`. `Stream#cards` builds a scoped query against `user.cards`. Streams are user-owned and uniquely named.

### Turbo Streams
All mutating actions (`create`, `update`, `destroy`) in cards and draft sub-controllers respond to `format.turbo_stream` for inline updates without page reloads. HTML fallback redirects are always provided.

### Routes

```
root                                        → home#index (redirects to /cards)

# Auth
resource  :session                          → sessions#create/destroy
resources :passwords, param: :token        → passwords#new/create/edit/update

# Cards
GET    /cards                               → cards#index (Timeline)
GET    /cards/:id                           → cards#show
GET    /cards/new                           → cards#new
POST   /cards                               → cards#create
GET    /cards/:id/edit                      → cards#edit
PATCH  /cards/:id                           → cards#update
DELETE /cards/:id                           → cards#destroy

# Card sub-resources (all Turbo Stream responses)
PATCH  /cards/:card_id/pop                  → cards/pops#update     (toggle/set pops_on)
PATCH  /cards/:card_id/pin                  → cards/pins#update     (toggle pinned status)
PATCH  /cards/:card_id/archive              → cards/archives#update (toggle archived status)
POST   /cards/:card_id/complete             → cards/completes#create  (mark done)
DELETE /cards/:card_id/complete             → cards/completes#destroy (unmark done)

# Dynamic form fields by cardable type
GET    /cards/fields/:id                    → cards/fields#show     (?id=task|note|draft)

# Drafts triage
GET    /drafts                              → drafts#index
POST   /drafts/:draft_id/schedule           → drafts/schedules#create  (promote → Task)
POST   /drafts/:draft_id/collect            → drafts/collects#create   (promote → Note)
POST   /drafts/:draft_id/postpone           → drafts/postpones#create  (set future pops_on)
POST   /drafts/:draft_id/remove             → drafts/removes#create    (destroy card)

# Other resources
resources :tags                             → tags#index/show/new/create/edit/update/destroy
resources :streams                          → streams#index/show/new/create/edit/update/destroy
resource  :calendar, only: :show           → calendars#show
resources :pinned,    only: :index         → pinned#index (pinned cards list)
resources :archived,  only: :index         → archived#index (archived cards list)
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
