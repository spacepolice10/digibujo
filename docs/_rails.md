# Rails

Rails 8.1.2 app. This is a framework-agnostic cheatsheet — not a Rails tutorial. It points at the conventions and patterns actually used here, and at upstream docs for everything else.

- **Upstream**: https://guides.rubyonrails.org
- **API reference**: https://api.rubyonrails.org
- **Reference projects** (all Rails 8+ + Hotwire + Lexxy):
  - [Fizzy](https://github.com/basecamp/fizzy) — closest match. Same auth pattern, same concerns style, same Lexxy usage.
  - [Writebook](https://github.com/basecamp/writebook) — best examples of service objects and Action Text forms.
  - [Campfire](https://github.com/basecamp/campfire) — best examples of Action Cable + Turbo Streams (real-time).
  - [Lexxy](https://github.com/basecamp/lexxy) — the editor gem (see `docs/_lexxy.md`).

## Stack pinned in `Gemfile`

| Gem | Version | Role |
|---|---|---|
| `rails` | `~> 8.1.2` | Framework |
| `propshaft` | latest | Asset pipeline (no Sprockets) |
| `importmap-rails` | latest | ESM imports, no Node build |
| `turbo-rails` | latest | Hotwire Turbo (see `docs/_turbo.md`) |
| `stimulus-rails` | latest | Hotwire Stimulus (see `docs/_stimulus.md`) |
| `lexxy` | `~> 0.9.18` | Action Text editor (see `docs/_lexxy.md`) |
| `sqlite3` | `>= 2.1` | Database for **all** environments |
| `solid_cable` / `solid_cache` / `solid_queue` | latest | DB-backed adapters (no Redis) |
| `puma` / `thruster` | latest | App server + HTTP accelerator |
| `kamal` | latest | Deployment |
| `bcrypt` | `~> 3.1.7` | Password hashing |

## Patterns in use

### Custom auth (not Devise)
- `app/controllers/concerns/authentication.rb` — included in `ApplicationController`; opt out per-controller with `allow_unauthenticated_access`.
- Session via `cookies.signed.permanent[:session_id]` (httponly, same_site: :lax).
- `Current.user` / `Current.session` via `ActiveSupport::CurrentAttributes` (`app/models/current.rb`).
- This is the Basecamp pattern; see Fizzy's `app/controllers/concerns/authentication.rb` for the same shape.

### Concerns for cross-cutting model behavior
- `app/models/concerns/` — `pinnable`, `collectable`, `poppable`, `completable`, `projectable`, `personable`, `bucketable`, `periodable`, `colourable`, `iconable`, `bulletable`.
- Each adds a scope + a small set of methods (`pin!`, `collect!(bucket_id:)`, etc.) mixed into models like `Bullet` and `Bucket`.
- **Namespaced concerns** for behavior that diverges per host: `Bullet::Archivable` (`app/models/bullet/archivable.rb`) and `Bucket::Archivable` (`app/models/bucket/archivable.rb`) wrap the `Archive` polymorphic entity. Mirrors Fizzy's `Card::Closeable` / `Card::Pinnable` namespace style. The flat shared `Archivable` concern was retired — Bullet and Bucket diverge on activity, migration stamping, and search-reindex side-effects, so one concern forced `after_archive!` / `after_unarchive!` hooks that masked real coupling. Each namespaced concern owns its own `archive!` / `unarchive!` transaction (INSERT/DELETE on `archives`, no `update!` on the subject) so `after_update` activity callbacks do not double-log.
- Same pattern as Fizzy / Writebook. See Fizzy's `app/models/concerns/` for the cleanest catalog.

### Delegated types for polymorphism
- `Bullet` uses `delegated_type :bulletable` with `Task`, `Note`, `Event` (`app/models/bullet.rb`).
- `Bucket` uses `delegated_type :bucketable` with `Collection`, `FutureBucket`, `MonthlyBucket` (`app/models/bucket.rb`).
- Reference: https://api.rubyonrails.org/classes/ActiveRecord/DelegatedType.html.

### Delegated types + nested attributes
- `Bullet` uses `delegated_type :bulletable` with `Task`, `Note`, `Event`, `Title` and declares `accepts_nested_attributes_for :bulletable` (`app/models/bullet.rb`).
- Each bulletable type declares which attributes it accepts from the bullet form via the `Bulletable.permitted_bullet_attributes` class method (concern default returns `[]`; `Note` overrides to `%i[mood]`). Controllers derive the strong-params permit list from the bulletable class named in `bulletable_type`, then guarantee `bulletable_attributes: {}` is present so the nested-attributes flow always has something to build from — even when the form submits no per-type fields (Task / Event / Title).
- Reference: https://api.rubyonrails.org/classes/ActiveRecord/DelegatedType.html, https://api.rubyonrails.org/classes/ActiveRecord/NestedAttributes/ClassMethods.html

### Action Text for rich text
- `Bullet#body` and `Bullet#rich_body` are Action Text fields, edited with Lexxy (see `docs/_lexxy.md`).
- `rich_body` is Note-only: only `app/views/bullets/composer/_note.html.erb` renders an editor for it. Task/Event/Title have no rich_body UI. Legacy non-Note bullets with rich_body still display via `rich_body?` in read views.
- Post-save content syncing uses `ActionText::RichText.find_by(record: bullet, name: 'body')` (`app/controllers/bullets_controller.rb`).
- Reference: https://guides.rubyonrails.org/action_text_overview.html.

### Active Storage for direct uploads
- `bullet.attachments` is `has_many_attached`; uploads go direct-to-storage via `DirectUpload` (`app/javascript/controllers/bullet_composer_controller.js`).
- Reference: https://guides.rubyonrails.org/active_storage_overview.html#direct-uploads.

### Variants for mobile
- `ApplicationController#set_variant` sets `request.variant = :mobile` for mobile user agents (`app/controllers/application_controller.rb`).
- Templates use `+mobile.erb` suffix; views branch on `request.variant.include?(:mobile)` (e.g. `app/views/layouts/application.html.erb`).
- Reference: https://guides.rubyonrails.org/layouts_and_rendering.html#the-virtual-path-option.

### Timezone per-request
- `ApplicationController#set_timezone` wraps actions in `Time.use_zone` based on a `timezone` cookie set by the `timezone-cookie` Stimulus controller.
- No `ActiveSupport::TimeWithZone` workarounds needed; everything goes through Rails' TZ system.

### Routes
- `config/routes.rb` — singular `resource :daylog`, scoped `module:` blocks for intent sub-controllers (`pins`, `collects`, `pops`, `archives`, `completes` under `bullets`).
- Full table in `AGENTS.md` under "Routes".

### SQLite for everything
- Separate DB files for primary, Solid Cache, Solid Queue, Solid Cable (`config/database.yml`, `cache.yml`, `queue.yml`, `cable.yml`).
- No Redis. No separate cache/queue processes. Solid Queue runs in-process with Puma.

### Testing
- Minitest with parallel execution and fixtures (`bin/rails test`).
- System tests via Capybara + Selenium (`bin/rails test:system`).
- See Fizzy's `test/` for the same shape with broader coverage.

## Rails guides to read (in order of usefulness here)

1. [Action Text](https://guides.rubyonrails.org/action_text_overview.html)
2. [Active Storage](https://guides.rubyonrails.org/active_storage_overview.html)
3. [Active Record Query Interface](https://guides.rubyonrails.org/active_record_querying.html)
4. [Active Record Delegated Type](https://api.rubyonrails.org/classes/ActiveRecord/DelegatedType.html)
5. [Action Controller Overview](https://guides.rubyonrails.org/action_controller_overview.html)
6. [Layouts and Rendering](https://guides.rubyonrails.org/layouts_and_rendering.html)
7. [Working with JavaScript in Rails](https://guides.rubyonrails.org/working_with_javascript_in_rails.html)

## When NOT to reach for Rails

- Real-time pubsub fanout at scale — Solid Cable is fine for thousands; beyond that, a real broker.
- Postgres-specific features (full-text search, JSONB indexing, advisory locks) — we're on SQLite.
- Background jobs at huge scale — Solid Queue is fine for thousands/day; beyond that, a real queue.
- Any frontend that needs rich client-side state — Hotwire covers most cases; reach for a framework only when you actually need one.
