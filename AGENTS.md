# AGENTS.md

This file contains agent workflow, architecture, and implementation guidance for this repository.

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

Bullets store three content layers: **`body`** (Action Text, Lexxy preset `inline` — short log line with `#` / `@` prompts), optional **`rich_body`** (Action Text, preset `expand` — code, files, markdown only; no `#` / `@` prompts and no tag sync), and **`attachments`** (`has_many_attached` — direct uploads via `bullet-composer` Stimulus, rendered in `_attachments.html.erb`, not inline in `body`). Rendered rich text uses `.rich-text-content` alongside Lexxy's `.lexxy-content`. **Project tags** use `bullet_projects` → `projects`; `Projectable` syncs join rows from `#` attachments in `body` on save (pills inline via `projects/_attachable`). **Person tags** use `bullet_people` → `people`; `Personable` syncs from `@` attachments in `body`. The unified composer (`bullets/_bulletable_form.html.erb`) is opened via **Add bullet**; type (Task / Note / Event) is chosen with a select (locked on edit). Note-only flags (mood, research, idea) toggle when Note is selected. Expand is always available and submits `rich_body` in the same form (blank `rich_body` is discarded on save). Paste/drop/file-picker on the inline editor are intercepted (`lexxy:file-accept`) and routed to direct attachments. **Bucket membership**: `Bullet` optionally `belongs_to :bucket` for **Collection** and **TimeSpread** only. **`Collectable`** sets or clears `bullets.bucket_id`; bulk collect picks a collection via `POST /bullets/collect` with `bucket_id`. Other intents (`Poppable`, etc.) update `triaged_at`, `pops_on`, `bucket` without type conversion.

### Bullet Status
`Bullet` has two independent boolean columns: `pinned` and `archived` (both `default: false, null: false`). There is no `status` enum. `Pinnable` adds a `pinned` scope and `pin!` / `unpin!` helpers (used by bullets and buckets; no pin count limit). `Archivable` adds an `archived` scope. The `timeline` scope returns all bullets (`all`) — pinned and archived bullets remain visible in the timeline and are distinguished by icons in the bullet partial.

`Bullet` also tracks `triaged_at` (`datetime`): `nil` means no organizing intent has stamped disposition yet; present means the user applied an action (e.g. collect or pop) that sets this timestamp.

### Daily log and `pops_on`
Bullets use `pops_on` (`date`) as the primary day bucket: which daily log page the bullet appears on. `Bullet.pops_on_date(date)` matches bullets for that calendar day per the model rules. The daily log is at `/daylog` (today) or `/daylog?date=YYYY-MM-DD`; pass `date:` to `daylog_path` when linking to another day.

### Monthly log spread
`MonthlyBucket` is a `bucketable` type (thin model + `Bucketable` + `Periodable`). The spread period lives on the monthly bucket itself via **`Periodable`** (`period_from`, `period_to`, `period_days`, `period_ranges_correct`). `period_from` is snapped to the 1st of the month. **`MonthlyBucket.current(user)`** returns the user's most recent monthly bucket, or `nil` (no auto-create). **`GET /monthly_bucket`** renders the current monthly bucket or an empty state. Specific spreads: **`GET /monthly_buckets/:id`**. Monthly buckets may optionally belong to a `FutureBucket`. Left column: bullets in the bucket with `pops_on` in `period_days`; right column: unplanned (`pops_on` nil). `pops_on` still places bullets on the daily log when set.

### Organizing from the timeline
Select bullets via row checkboxes; the sticky **`_bulk_menu`** (styled in `bulk-menu.css`, driven by `bulk-menu` Stimulus on the page wrapper) keeps selection in **`idListValue`** and syncs a comma-separated `bullet_ids` CSV into every `data-bulk-menu-target="idList"` hidden field.

**Direct intents (no UI fetch):** **pin**, **archive** — `POST`/`DELETE` with `turbo_stream` from menu forms.

**UI fetch then intent:** **pop** and **collect** — `openPopsPicker` / `openCollectsPicker` set frame `src` with `bullet_ids` from `idListValue`, then `showPopover()` (lazy turbo-frame + popover, like pinned footer); picker POST/search forms use `data-bulk-menu-target="idList"` (synced on `idListTargetConnected` and `idListValueChanged`). Collect picker search reloads the `collects_picker_frame` via GET with `q`. Menu embeds search via `turbo-frame#menu_search` (`GET /search`, turbo-stream for live input); menu shell is `GET /menu`. Lexxy `#` / `@` suggestions use `filter`.

**Pop intent:** `POST /bullets/pop` with `pops_on` (`DELETE` to restore previous day). **Collect intent:** `POST /bullets/collect` with `bucket_id` (`DELETE` uncollects the selection). **Postpone** on the daylog is `POST /bullets/pop` with `pops_on` = viewing day + 1. Pin/Unpin buttons hide when the selection includes a pinned or unpinned bullet respectively (`data-pinned` on checkboxes). Activity records `popped` and `collected`; reports infer moves from `pops_on` changes. Project/person tag changes from Lexxy attachments record `project_tagged` / `project_untagged` and `person_tagged` / `person_untagged`. Responses use Turbo Streams where applicable, with HTML fallbacks.

`Collectable` and `Poppable` are intent-focused concerns; they do not force bullet type conversion.

### Sweep Rules
`SweepCardsJob` (name unchanged) operates on `Bullet` and enforces recycling rules:

- completed bullets remain recyclable through `archives_on` (set by `Completable#complete!`)
- bullets are auto-archived when due (`archives_on <= today`) or still untriaged after a grace window
- pinned bullets are excluded from auto-archive and deletion
- archived bullets are hard-deleted only after a retention period, and pinned bullets are excluded there too

### Analog BuJo Alignment
The architecture is intentionally closer to analog Bullet Journal behavior:

- **Rapid logging** uses one **Add bullet** composer with a type select (Task / Note / Event); inline `body` by default, Expand for optional `rich_body`
- **Daily focus** is explicit (`/daylog` and dated daylog paths show the daily log)
- **Migration over rewrite** happens where needed by editing or changing bullet type
- **Deferred decisions** are supported by moving `pops_on` forward (postpone) or tagging a project
- **Separation of concerns** mirrors BuJo pages: today/timeline, archived, pinned

### Projects (tags)
`Project` is a first-class model (`belongs_to :user`) with `name`, `colour`, `icon`, and `pinned` (`Colourable`, `Iconable`, `Pinnable`, `ActionText::Attachable`). Bullets link via `bullet_projects` (many-to-many; a bullet may have several project tags). `GET /projects/:id` lists bullets joined through `bullet_projects`. Project show composer passes `default_project_id` so new bullets hydrate with that tag in the editor. Pin/unpin uses `POST`/`DELETE` on `projects/pin`. `Person` mirrors the same pin/unpin pattern via `people/pin` on the person show page.

### Buckets and memberships
`Bucket` belongs to a user and uses `delegated_type :bucketable` (`Collection`, `Bundle`, `FutureBucket`, `MonthlyBucket`). `MonthlyBucket` includes **`Periodable`** for time restrictions (`period_from` / `period_to`). Each bullet has **zero or one** bucket via `bullets.bucket_id` for collection/bucket membership. `Collection` rows do not store `user_id`; ownership is the bucket’s `user_id`, with `creation_user_id` on the bucketable for attribution where needed. Bucket **identity** (`name`, `colour`, `icon`) is stored on `buckets` (`name` required; `colour` / `icon` optional via `Colourable` and `Iconable`; no auto-assign). Collection bucket names are unique per user. `Collection` is a thin delegated type (no identity columns); it delegates `name`, `colour`, `icon`, and colour CSS helpers to `bucket` for display. Create forms pass identity fields on the bucketable param object; controllers persist them on the bucket row. The home hub is at `GET /home` (linked from the app header). **Streams** (saved filtered views) were removed; use projects, collections, and timeline filters instead.

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
GET    /monthly_buckets/:id                  → monthly_buckets#show
GET    /monthly_buckets/new                  → monthly_buckets#new
POST   /monthly_buckets                      → monthly_buckets#create
GET    /monthly_buckets/:monthly_bucket_id/bullets/new → monthly_buckets/bullets#new
POST   /monthly_buckets/:monthly_bucket_id/bullets     → monthly_buckets/bullets#create
resources :bundles, only: %i[show new create destroy]

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
PATCH  /bullets/:bullet_id/publish           → bullets/publishes#update
GET    /bullets/export                       → bullets/exports#show

# Search & menu
GET    /search                               → searches#show (?q=; turbo-stream updates menu_search frame)
GET    /menu                                 → menu#show (?q= pre-fills search field)
GET    /notes                                → notes#index

# Home, buckets, future
GET    /home                                 → home#show (navigation hub)
PATCH  /home/sections/:id                    → home/sections#update (persist section open/close state)
GET    /buckets/:id                          → buckets#show (footer popover bullet list)
POST   /buckets/pin                          → buckets/pins#create
DELETE /buckets/pin                          → buckets/pins#destroy
GET    /future                               → futures#show
POST   /future                               → futures#create
POST   /future/months                        → futures#months

# Projects, people, collections
GET    /projects/suggestions                 → projects/suggestions#index (Lexxy `#` prompt items)
POST   /projects/pin                         → projects/pins#create
DELETE /projects/pin                         → projects/pins#destroy
resources :projects, only: %i[index new create show destroy]
GET    /people/suggestions                   → people/suggestions#index
POST   /people/pin                           → people/pins#create
DELETE /people/pin                           → people/pins#destroy
resources :people, only: %i[index new create show destroy]
resources :collections, only: %i[index new create show destroy]

# Views
GET    /activities                           → activities#index (?bullet_id= optional)
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
