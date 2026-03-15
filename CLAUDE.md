# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Digibujo is a Rails 8.1 application using the modern "Omakase" stack: SQLite everywhere (including cache/queue/cable via Solid gems), Hotwire (Turbo + Stimulus) for interactivity, Propshaft for assets, and Importmap for zero-build JavaScript. Deployed with Kamal via Docker.

## Core Philosophy

The app eliminates friction in information capture by allowing users to dump any content into a unified Timeline without requiring upfront categorization or formatting decisions. Organization happens later through intentional, periodic revision workflows.

---

## Card System

### Card Types (Implemented)
- **Draft:** Raw capture state — the default when creating a card. Triaged during revision into a Task or Note.
- **Task:** Actionable item with completion state (`done`/`done_at`). Temporal and completable.
- **Note:** Tagged permanent card for knowledge/reference storage.

> Planned types (not yet implemented): Events, Checklists, Links, Files, Journal Entries.

### Bullet Journal Markers
Visual indicators for quick card type identification and switching:
- `•` Task
- `-` Note
- `○` Event
- Additional markers as needed

**Input Methods:**
- **Desktop:** Type markers directly (e.g., type `•` to create a task)
- **Mobile:** UI chips/buttons for quick marker selection

### Auto-Tagging System
Cards are automatically indexed by:
- **Card type** (task, note, event, etc.)
- **Dates** (creation, scheduled, due dates)
- **Locations** (geo-tags if available)
- **People** (mentions or associations)
- **Custom tags** (user-defined keywords)

---

## Core Workflows

### 1. Capture
**Goal:** Frictionless content entry without formatting requirements

**Process:**
1. User writes/pastes/attaches content
2. System creates card in Timeline
3. Optional: User adds marker or quick tags
4. Card enters Timeline without requiring categorization

**Key Principle:** Capture first, organize later

---

### 2. Revision
**Goal:** Periodic intentional organization of accumulated content

**Trigger:**
- User-defined period (default: weekly)
- Can be customized per user preference

**Process:**
1. All untagged cards surface at top of Timeline
2. Cards appear with action buttons
3. User can dismiss revision prompt temporarily
4. System remembers which cards have been through revision

**Available Actions:**
- **Mark Done:** Complete and archive the card
- **Schedule:** Set date/time for future action
- **Delete:** Permanently remove the card
- **Tag as Resource:** Add tags and move to persistent Resources area

**Cards Not Revised:**
- Move to Archive after first revision period
- Auto-delete from Archive after 30 days

---

### 3. Organization Areas

#### Timeline
- **Purpose:** Main chronological feed of all active cards
- **Content:** All cards except Set Aside and Archived
- **Sorting:** Reverse chronological by default
- **Access:** Primary view for daily interaction

#### Set Aside (Pinned)
- **Purpose:** Priority cards that need frequent access
- **Limit:** 10 cards (`Pinnable::PIN_LIMIT`)
- **Implementation:** `pinned: true` boolean on the `Card` model; accessible at `/pinned`
- **Special Feature:** Accessible offline
- **Location:** Outside Timeline, always visible/accessible
- **Use Cases:** Current priorities, recurring references, active projects

#### Resources
- **Purpose:** Persistent knowledge base
- **Content:** Tagged cards intended for long-term storage
- **Characteristics:** Does not auto-delete, searchable via Index
- **Use Cases:** Reference notes, documentation, saved ideas

#### Archive
- **Purpose:** Temporary holding for unprocessed cards
- **Entry Condition:** Cards not tagged during first revision
- **Exit Condition:** Auto-delete after 30 days
- **Use Cases:** Grace period for forgotten cards, reduces Timeline clutter

---

## User Interface

### Three-Page Structure

#### 1. Index
**Purpose:** Discovery and navigation via metadata

**Features:**
- Search functionality across all cards
- Browse by tags
- Browse by people
- Browse by locations
- Browse by dates
- Filter combinations

#### 2. Timeline
**Purpose:** Main working area for daily capture and interaction

**Features:**
- Chronological card feed
- Quick card creation
- Inline editing
- Revision prompts (when due)
- Drag-to-reorder or quick actions

#### 3. Log (Calendar)
**Purpose:** Time-based view of cards

**Features:**
- Calendar interface
- Shows time-related cards (events, scheduled tasks, dated entries)
- Day/week/month views
- Quick scheduling from calendar

---

## Collaboration Features

### Async Card Editing
- **Mechanism:** Multiple users can access and edit shared cards
- **Timing:** Not real-time; changes sync asynchronously
- **Use Cases:** Shared task lists, collaborative notes, team resources

### Quick File Sharing
**Process:**
1. Attach file to card
2. Select collaborator(s)
3. Share card with file attached
4. Recipients can access and edit

---

## Publishing Features

### Web Publishing
- **Style:** Similar to Hey World (simple, clean blog-style)
- **Mechanism:** Select cards to publish publicly
- **Use Cases:** Sharing notes, creating public documentation, simple blogging

---

## Advanced Features

### Repeatable Checklists
- **Function:** Template cards that can be quickly recreated
- **Process:**
  1. Create checklist card
  2. Mark as template
  3. Spawn new instances from template when needed
- **Use Cases:** Recurring workflows, standard procedures, habit tracking

### AI Augmenters
- **Technology:** MCP (Model Context Protocol) support
- **Capabilities:**
  - Auto-sorting cards by type/context
  - Auto-tagging based on content analysis
  - Data modification and enhancement
  - Content summarization
  - Action item extraction
- **Implementation:** Skills/plugins that process card data

### Third-Party Integrations

#### iCal Calendar Integration
- **Import:** Pull events from external calendars
- **Export:** Push scheduled cards to calendar apps
- **Sync:** Bidirectional updates (potential)

#### Future Integrations
- Email dumps
- Read-later services
- Note-taking apps
- Project management tools

---

## Technical Considerations

### Offline Functionality
- **Set Aside cards:** Always accessible offline
- **Recent Timeline:** Cache for offline viewing
- **Sync:** Changes sync when connection restored

### Auto-Removal Logic
1. Card created → enters Timeline
2. First revision period → if not tagged, moves to Archive
3. 30 days in Archive → permanent deletion
4. Exception: Tagged/Resources cards never auto-delete

### Revision Period Configuration
- **Default:** 7 days (weekly)
- **Customizable:** Per user preference
- **Notification:** Prompt when untagged cards accumulate
- **Dismissible:** Can postpone revision without penalty

---

## User Experience Principles

1. **Capture should be instant** - No friction, no required fields
2. **Organization is intentional** - Happens during dedicated revision time
3. **Everything has a place** - Clear paths from capture to archive/resources
4. **Offline-first for priorities** - Set Aside works without connection
5. **Progressive disclosure** - Simple capture, advanced features available when needed
6. **Flexible but opinionated** - Smart defaults with customization options

---

## Open Questions / Future Considerations

- Migration workflows (BuJo-style moving uncompleted tasks forward)
- Advanced filtering and smart views
- Card dependencies/relationships
- Notification system for scheduled cards
- Mobile app vs PWA approach
- Data export and portability
- Privacy controls for shared cards
- Version history for edited cards

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
