# Architecture

Application architecture and implementation conventions for Digibujo — a digital Bullet Journal built on Rails 8, Hotwire, and SQLite.

Framework-agnostic references live in [`docs/`](docs/). Agent workflow rules live in [`AGENTS.md`](AGENTS.md).

## Authentication

Custom session-based auth built with an `Authentication` concern (not Devise). **Passwordless:** users continue with email + one-time code (`AuthCode`). `AuthenticationController#create` finds or creates the `User`, sends a code, and stores `session[:login_email]`; `Authentications::ConfirmationsController#create` calls `AuthCode.consume!` and always starts a session, then redirects to `onboarding#new` unless `user.onboarded?`, otherwise to the app. `OnboardingController` (authenticated) still exists: `Onboarding#complete` provisions `Loose Notes`, the single `Daylog`, and the single `Pending`, then sets `users.onboarded`. Monthlylog / Future remain opt-in. Logout via `DELETE /authentication`. Persisted sessions live in the `sessions` table; the signed httponly cookie holds `session_id`. `Current.user` / `Current.session` via `ActiveSupport::CurrentAttributes`. Controllers opt out of auth with `allow_unauthenticated_access`. The continue-with-email form links to **`GET /features`** (`FeaturesController#show`) and **`GET /support`** (`SupportController#show`), both unauthenticated with `layout: public`. Rate limiting is applied to authentication create, confirmation create, and onboarding create. Auth forms use a `form-submit` Stimulus controller for submit loading state.

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

**Daylog bullets:** `GET /daylog/bullets.json?before=<id>` — cursor paging; **200** array, **204** exhausted/unknown, **304** when `If-None-Match` matches ETag. **Create:** `POST /bullets.json` → **201** + `Location` + bullet body; validation → **422**. Bullet JSON: `id`, `bulletable_type`, `pops_on`, `bucket_id`, `pinned`, `archived`, `migrated_at`, `body`, `body_html`, type-specific fields, timestamps, `url`.

**Hooks** (inbound intake for external apps → Pending inbox):

- Manage (session or access code): HTML **Account → Hooks** — index lists hooks + Create; **`GET /hooks/new`** form (payload docs); create shows intake URL once via flash on index. JSON `GET/POST /hooks.json`, `DELETE /hooks/:id.json`. Create body: `{ "hook": { "name" } }` → **201** with `code` once (`hk_…`) and `url` (`POST /hooks/:code`).
- Intake (unauthenticated): `POST /hooks/:code` with `{ "author_name", "bulletable_type", "body" }` → creates a bullet in that user's **Pending** bucket (`pops_on` nil). Allowed types: `Note`, `Task`. **201** + bullet JSON; unknown/inactive code → **404**; bad type/validation → **422**. The intake `code` is hashed at rest (same pattern as access codes) but only authorizes Pending create — not full API access.

## User Settings

Per-user settings live in a dedicated `user_settings` table (one row per user), accessed via `User::Configurable` concern. `User` `has_one :settings, class_name: "User::Settings"`; the row is created automatically on user create. `User::Settings` exposes typed columns and a `SECTIONS` / `SECTION_COLUMNS` map (current sections: `logs`, `projects`, `collections`, `published` → `*_expanded` booleans). **`appearance`** (`default`, `warm`, `cool`, `nature`, `cheese`) drives the home background tint. Add new settings as real columns and extend the model; avoid JSON columns. Home section expand/collapse is updated via `POST /home/sections/:id/expand` and `POST /home/sections/:id/collapse` (`Home::SectionsController`), which guards unknown keys using `User::Settings::SECTION_COLUMNS`. Appearance is updated via `POST /home/appearance` (`Home::AppearancesController`). The concern also exposes `User#settings!` which lazy-creates the row on first access; use it from controllers so users created before the row existed (or created via raw SQL) still get a settings record.

## Delegated Type Pattern (Bullets)

`Bullet` uses `delegated_type :bulletable` with `inverse_of: :bullet` for polymorphism. The `bullets` table holds `bulletable_type`/`bulletable_id`. Implemented bulletable types:

| Type    | Concerns     | Notes                              |
|---------|--------------|------------------------------------|
| `Task`  | `Bulletable` | Completable + temporal |
| `Note`  | `Bulletable` | Long-form |
| `Event` | `Bulletable` | Temporal; date range |
| `Voice` | `Bulletable` | Audio memo; body is the caption |

Each bulletable includes **`Bulletable`** (`has_one :bullet`, `has_rich_text :body`, display defaults, `to_partial_path`, `permitted_bullet_attributes`). **Every type stores `body` as Action Text (Lexxy)** — there are no plain `body` columns. **`Bulletable#body_as_text`** is the `to_plain_text` form; **`#name`** is its first line, **`#long?`** compares it against `EXCERPT_LIMIT`, and **`#excerpt`** returns the rich `body` for short bodies and a truncated plain-text tail for long ones. **`Bullet` delegates `:body` / `:body_as_text`** (and type-specific display helpers) to the bulletable. Create/update params nest body under `bulletable_attributes`.

**Create** uses the chat composer only ([`bullets/_composer`](app/views/bullets/_composer.html.erb)). **Edit** uses a single body-only form ([`bullets/_edit_form`](app/views/bullets/_edit_form.html.erb)): Lexxy `note` for Notes, `inline` for Task/Event/Voice; type / bucket / `pops_on` are not accepted on update. Rendered rich text uses `.rich-text-content` alongside Lexxy's `.lexxy-content`. **Projects** sync from Action Text `#` attachables on **every** bulletable type. Each type declares permitted attributes via `permitted_bullet_attributes`.

**Bucket membership:** `Bullet` **requires** `belongs_to :bucket` (Daylog, Monthlylog, Future, Collection, or Pending). **`bucket_id` must belong to the same user** and must be supplied on create (composer hidden field). Homes are exclusive: the daylog page never unions monthly/future/pending bullets. **`Migratable#migrate_to!`** moves a bullet to a destination with an explicit BuJo `action` (`collected` or `rescheduled`) and a caller-resolved `pops_on`. **`Collectable#collect!`** and **`Postponable#postpone!`** own destination/`pops_on` rules and call that API. There is no uncollect — migration is one-way. **`Bullet#accept_from_pending!`** is the Pending → today Daylog shortcut (`rescheduled`).

### Composer UX

All bullet types are created via **`POST /bullets`** (`BulletsController`) — there are no nested create routes. (`GET /daylog/bullets` exists, but only serves older chat pages; see **Chat daylog**.)

**Chat composer** ([`bullets/_composer`](app/views/bullets/_composer.html.erb), `chat-composer` Stimulus): a fixed dock mounted on daylog, collection, and monthlylog pages (`bottom` clears the floating tabbar / iOS keyboard). Callers pass `bucket_id`, optional `pops_on`, **`variants`** (allowlist; default Note/Task/Event; daylog adds Voice), and **`composer_id`** (turbo-frame id paired with the list). One Lexxy `note` editor serves every type; a hidden `bulletable_type` field is switched by the type picker from `variants` (Voice is never a picker row — mic only, and only when Voice is in `variants`) and the last pick is remembered in `localStorage`. **`changeContext({ bucketId, popsOn, variants, composerId })`** updates hidden fields, picker/mic visibility, and the turbo-frame id without remounting Lexxy (monthlylog date ↔ unplanned). On desktop Notes submit with Cmd/Ctrl+Enter (plain Enter inserts a newline); Task/Event submit with Enter. On touch / coarse pointers neither Enter nor Cmd/Ctrl+Enter sends — use the submit control. Shift+Enter breaks the line, and neither sends while the formatting toolbar is open or a Lexxy prompt menu is open. Field clicks focus the editor except when they land on Lexxy toolbar / dropdown chrome (so menus stay open). Compact is one pill: type | editor | formatting `+` (Note) | mic | submit. The row latches `composer--multiline` via a `ResizeObserver` once the editor grows past its blank height (or an attachment lands). Multiline **detaches** the field into its own floating pill above a height-0 / transparent Lexxy toolbar slot and a transparent chip strip (type / clear trash / formatting `+` / mic / submit). The editor grows with content up to the viewport (minus dock chrome / tabbar-or-keyboard inset and a top breathing band), then scrolls inside. A Note-only formatting control (icon `plus`, Shift+Ctrl+E) is always available for Notes; it expands `<lexxy-toolbar id="composer_toolbar">` (linked via `toolbar="composer_toolbar"` — never reparented) to control height with horizontal scroll: between the field and the chip strip when multiline, wrapping under the whole row when compact. **`<lexxy-toolbar>` must stay ahead of `<lexxy-editor>` in the DOM** — visual placement is `order` in `composer.css`. Lexxy registers `lexxy-toolbar` before `lexxy-editor` so a cold load upgrades them in the right sequence, but on a Turbo body swap the elements are already defined and upgrade in document order; an editor that connects first calls `setEditor` on a plain, un-upgraded toolbar, which throws inside `connectedCallback` and leaves Lexical unmounted (a bare `contenteditable` with a duplicated placeholder). The closed slot keeps its own flex line at zero size (`inert`, transparent, no border) so both the reveal and the collapse transition; the row carries `row-gap: 0` and the lines that need air use `margin-block-start` instead, which animates. File and image upload live only on that Lexxy toolbar (`data-upload="both"`), not as separate actions chips. No remount, no full-screen sheet. Starting a voice take **swaps the compose row** for a matching pill shell (`composer--rail-recorder`): pause on the left, live waveform in the middle, send on the right; discard appears after the take is stopped. Lexxy token map + editor overrides live in [`composer.css`](app/assets/stylesheets/composer.css) (loaded after `lexxy` in the layout) — there is no separate `actiontext.css`.

**Composer voice mode:** the mic button hands control to `voice-recorder` on the same element (`manage-submit: false`, so the composer owns the submit button and reacts to `voice-recorder:change` / `voice-recorder:denied`). The editor is hidden while recording; a blank caption is filled in server-side by `Voice#apply_default_caption`.

**Inline create responses:** the composer posts from a `<turbo-frame id="…_bullets_composer">`, so `BulletsController#create` reads `turbo_frame_request_id` and [`create.turbo_stream.erb`](app/views/bullets/create.turbo_stream.erb) appends to the paired `…_bullets_container` (string swap `bullets_composer` → `bullets_container`, else `/_composer\z/` → `_container`). Daylog uses stable `daylog_bullets_*`; collections use `dom_id(..., :bullets_composer|/container)`; monthlylog uses short ids `date_<iso>_bullets_*` and `monthlylog_bullets_unplanned_*`; future uses `future_bullets_unplanned_*`. Monthlylog/Future rows use their `…/bullets/bullet` drag wrappers. Failures render a toast (422). Plain HTML create redirects to the bullet show. Pending **Today** accept appends to `daylog_bullets_container`.

**Edit:** [`GET/PATCH /bullets/:id/edit`](app/views/bullets/edit.html.erb) — body-only form ([`bullets/_edit_form`](app/views/bullets/_edit_form.html.erb)); no type picker. Back returns to the bullet show page.

**Monthly spread:** parked page-level composer; each column has **Create bullet**, which docks the shared Lexxy node into that column (view-transition morph). `monthlylog-composer` sets Task/Event vs Note via `changeContext`; Esc parks again. The CTA stays in the dock (holds idle height) and is only visually replaced while composing. Mobile: composer mounts into the date dock immediately, full `100dvh` lock, no scroller `overscroll-behavior: contain` so horizontal section snaps chain; IntersectionObserver on docks moves the composer between columns.

**Future log (temporary):** same chat chrome as daylog — floating header, `chat--wrap` / `chat--scroller`, fixed composer — but only unplanned bullets (`future_bullets_unplanned_*` ids; Task/Note). Month-card UI is parked until a better design lands.

## Chat surfaces

Shared list chrome lives in [`chat.css`](app/assets/stylesheets/chat.css): `chat--wrap`, `chat--scroller`, `chat--compact-list-pinned`, `chat--load-more-trigger`. Stimulus `chat-scroll` (was `daylog-scroll`) owns cursor paging. Daylog chrome (header / mood / photo) stays `daylog--*`.

**Daylog:** Messages column without an html/body scroll lock. Day chrome (date nav / mood / picture) is a **floating island** over the scroller (same pill language as the tabbar). The chat composer is the same **fixed dock** as on collections/monthlylog/future: `bottom` clears the tabbar when the keyboard is closed, and switches to the visualViewport keyboard inset when open (tabbar hidden so it cannot overlap the dock). Document may pan on iOS focus; the dock still tracks the keyboard. On desktop the Digibujo header stays above the column.

**Future:** Same chat shell as daylog for now (floating name/pin island + scroller + composer), scoped to unplanned bullets only.

**Cursor paging** (`Bullet::Pageable`): `last_page` takes the newest `PAGE_SIZE` rows in reading order (`chronologically.last(n)` — reversed in SQL, no OFFSET), `page_before(bullet)` takes the batch just older than a cursor, breaking `created_at` ties on `id`. `DaylogsController#show` renders `last_page` and sets `@more_bullets` when it came back full; **`GET /daylog/bullets?before=<id>`** (`Daylogs::BulletsController#index`) renders bare rows for the page before the cursor and answers **204** once nothing older is left (also for unknown or foreign cursors). Offsets would drift here, because the composer keeps appending to the end of the same list.

**Short-list pin (CSS):** `.chat--compact-list-pinned` is `min-height: 100%` with `justify-content: flex-end`, so a sparse list packs against the composer without putting `.chat--load-more-trigger` in view (which would auto-fetch every page). Once the list overflows the scrollport, free space is gone and the feed reads top-to-bottom as usual. Empty state lives inside the list so the pin still applies.

**Scrolling** (`chat-scroll` + [`helpers/scroll_helpers`](app/javascript/helpers/scroll_helpers.js)): open at the bottom; an `IntersectionObserver` on `.chat--load-more-trigger` fetches the next older page and prepends it inside `keepScroll`, which restores the distance to the bottom edge so the row being read never moves. `pauseInertiaScroll` clamps overflow for a frame first, or iOS momentum would override the write. The observer is re-armed after each prepend (it only reports *changes*, so a trigger still on screen would otherwise go quiet), and the loop ends when the new rows push it out of range or the endpoint answers 204. New rows follow the reader only while they are already at the bottom — tracked on every scroll event, deliberately unthrottled, since a dropped trailing call would leave the list yanking itself down under someone reading history.

## Bullet row rendering

List views use **`<%= render partial: bullet.to_partial_path, locals: { bullet: bullet } %>`**, which resolves `Bullet#to_partial_path` → type row (`tasks/task`, `notes/note`, …) with local name forced to `:bullet`. Each type row wraps layout [`bullets/_bullet`](app/views/bullets/_bullet.html.erb) (turbo-frame, inline marker + migration metadata) and yields type-specific content. Completed tasks set `data-task-completed` and strike through `.bullet--body`. Migration markers open an anchored dropdown (same chrome as pinned/create) with the migration hint — they do not navigate to the activity show page.

- **Wrappers:** `reviews/_bullet`, `monthlylogs/bullets/_bullet`, `futures/bullets/_bullet`, `pendings/_bullet` — surface shells around the type row render (pending adds the Today accept control).

## Bullet Status

`Bullet` has a `pinned` boolean column (`default: false, null: false`). Archive state is **not** a column — it lives in a separate polymorphic `Archive` entity (see **Archive entity** below). There is no `status` enum. `Pinnable` adds a `pinned` scope and `pin!` / `unpin!` helpers (used by bullets and buckets; no pin count limit). **`Archivable`** adds `archived` / `active` scopes backed by the `archives` join. Daylog and other list views use the **`active`** scope to hide archived bullets; pinned bullets remain visible and are distinguished by icons in the marker.

`Bullet` tracks **`migrated_at`** (`datetime`, nullable) and **`last_migration`** (json, default `{}`). BuJo moves go through **`Migratable#mark_migration!`** with action `collected` or `rescheduled` (and matching Activity). **`Task#complete!`** only sets `migrated_at` (and clears `last_migration`) so the bullet leaves the review inbox — it is not a BuJo migration action. Archiving does **not** stamp `migrated_at`. `migrated?` is `migrated_at.present?`. Row markers use `collected_migration?` / `rescheduled_migration?` plus `migration_hint` in an anchored dropdown. Project tags do **not** stamp migration.

## Archive entity

Archiving (`Bullet` or `Bucket`) is modelled as a row in **`archives`** (`archivable_type` / `archivable_id` polymorphic, `user_id`, timestamps), mirroring `PinnedEntity`. A unique index guarantees at most one `Archive` per subject. `Archive#created_at` replaces the old `archives_on` column; `Archive#user_id` records who archived.

**`Archivable`** (shared concern on Bullet and Bucket) provides `has_one :archive`, `archived` / `active` / `expired_archived` scopes, and `archive!` / `unarchive!` (create/destroy the join row only). Lifecycle side effects live on **`Archive`**:

- `after_create` records Activity with **`subject: Archive`**, action `archived`, metadata snapshot (`name`)
- `before_destroy` records `unarchived` the same way (skipped when the Archive is destroyed via `dependent:` on the archivable)
- `after_create_commit` / `after_destroy_commit` call `archivable.reindex` so search stays in sync (archive is not an `update!` on the subject)

`Bullet::Searchable` and `Bucket::Searchable` both use `searchable? { !archived? }`. Review inbox scopes **`.active`** (and `migrated_at: nil`) so archived bullets leave review without a migration stamp. `archives_on` remains a shim (`archive&.created_at&.to_date`) for views and tests.

## Activity

`Activity` is a polymorphic audit log: **`subject`** (`Bullet`, `Bucket`, or `Archive`), **`action`** (string from a flat `Activity::ACTIONS` list), **`metadata`** (json), **`user_id`**. Recording goes through **`ActivityTrackable#record_activity!`** on subjects, except archive/unarchive which are written from `Archive` callbacks and pin/unpin from `PinnedEntity` callbacks. Actions: `updated`, `collected`, `rescheduled`, `completed`, `uncompleted`, `pinned`, `unpinned`, `project_mentioned` / `project_unmentioned`, `created`, `destroyed`, `archived`, `unarchived`. Bucket `created` is recorded from controllers (collections/monthlylogs); `destroyed` from `CleanSoftDeletedRecordsJob` before hard delete (snapshots `name` / `colour` / `bucketable_type`). Bucket activities are retained after hard delete so `destroyed` rows remain until swept. BuJo migrate intents (`postpone!` → `rescheduled`, `collect!` → `collected`) write bullet activities with migration payload in `metadata`. Complete records Activity `completed` and sets `migrated_at` only. Feed copy is built by **`ActivitiesHelper#activity_sentence`** (links via `polymorphic_path`). **`GET /activities`** lists the user's global feed (no subject filter). **`GET /activities/compact`** returns the latest six activities for the home rail.

## Tracker

`Tracker` is a habit grid **on a Monthlylog** (`belongs_to :monthlylog`). One mark per calendar day via **`Tracker::Completion`**. Not a bullet — no archive or sweep. Identity uses **`Colourable`** / **`Iconable`**.

**Schedule** (`schedule` json): `{ "days" => […] }` with Ruby `wday` 0–6 (defaults to every day). Active range is the monthlylog period. No `stop!` lifecycle — delete the tracker or leave it for the month.

**UI:** create from monthlylog show (`POST /monthlylogs/:id/trackers`). Tracker show page has the month heatmap. Toggle posts to `POST`/`DELETE /trackers/:id/completion`. (Per-day tracker toggles on the monthly calendar date panel are a follow-up.)

## Mood tracker

Optional day-level artifacts on **Daylog**: **`Daylog::MoodEntity`** (`daylog_mood_entities`: `date` + mood enum) and **`Daylog::Picture`** (`daylog_pictures`: `date` + Active Storage `picture`). Mark/clear via `POST`/`DELETE /daylog/mood_entity` and `POST`/`DELETE /daylog/picture` (`Daylog#pick_mood` / `#remove_mood` / `#remove_picture`); mobile daylog also fetches the card via `GET /daylog/picture`. Mood picker posts with `data-turbo-stream` and replaces `daylog_mood_entity_<iso-date>` in place (HTML fallback still redirects back). Monthly show preloads `CalendarDate` pictures for calendar cell thumbs and paints a single accent presence indicator from planned-bullet counts; mood/tracker chrome on the date panel is a follow-up. On the daylog page the day header levitates over the chat; mood and picture are separate header controls.

**Day photo presentation** uses a single card shell on every viewport ([`daylogs/_photo_card`](app/views/daylogs/_photo_card.html.erb), id `daylog_photo_card_<iso-date>`), driven by one `daylog-photo` Stimulus controller wrapping the card + chat shell so the header control can toggle it:

| Viewport | Collapsed look | How it opens |
|----------|----------------|--------------|
| Wide desktop (≥ `--breakpoint-pc`) | Card tucked behind the panel's right edge with a peeking sliver | Click the sliver (or the header arrow) |
| Narrow desktop | Card parked fully past the right edge of the viewport | Header arrow (camera becomes ← once a photo exists) |
| Mobile (`request.variant = :mobile`) | Card **not in the DOM** until shown | Header arrow fetches [`GET /daylog/picture`](app/controllers/daylogs/pictures_controller.rb) (`show`, layout-free fragment) into the shell, then flies it in; collapse unloads the fragment again |

Expand and delete live on a frosted toolbar overlaid on the card itself (`daylog--photo-toolbar`), not in the day header. The header picture control is only: camera upload when empty, arrow toggle when a photo is attached. There is no photo-as-header-background.

The `daylog-photo` controller toggles classes only: `is-expanded` runs `daylog-photo-fly-out`, `is-collapsing` runs `daylog-photo-fly-in` (removed on `animationend`). Both keyframes make the same trip — out to `--daylog-photo-out`, where the whole card is past the panel/viewport edge, **then** the `z-index` flip, then back to the resting spot — so the layer never changes while any part of the card overlaps the bullet list. Overshooting the viewport is fine: the card is `position: fixed`, so nothing reflows. Esc / outside click collapse (clicks on the card or the header picture control are ignored).

**Display always uses resized Active Storage variants** (`ImageVariant` + named variants on `Daylog::Picture`; `represent_image_tag` for note attachments / the attachment show page) — never the original blob on screen. Picture create/destroy streams replace `daylog_picture_<iso-date>` and `daylog_photo_card_<iso-date>` (mobile streams keep the photo shell empty / lazy). Daylog chat has a desktop `show` and `show.html+mobile` that share `_chat`. Notes no longer carry mood.

## Review

**`GET /review`** (`ReviewsController#show`, `?from=YYYY-MM-DD&to=YYYY-MM-DD`, defaults to the last 7 days through yesterday — today's bullets stay out of review) lists bullets that still need triage for the period:

```ruby
Current.user.bullets.in_review(@review_from..@review_to)
```

(`Bullet.in_review` = daylog bucket + `pops_on` in range + `migrated_at: nil` + `.active`)

- **Daylog home only** — monthly/future/collection bullets are excluded.
- **`pops_on` must be set** — unplanned bullets (`pops_on` nil) are excluded.
- **Already migrated** bullets are excluded (`migrated_at` set by pop, collect, or complete).
- **Archived** bullets are excluded via the **`active`** scope.

Leaving the inbox is done via collect, postpone, complete, or archive — there is no separate “mark reviewed” action.

**Review UI (desktop, `show.html.erb`):** 3-column workspace in `review.css` (`height: 90dvh` like monthlylog spread; flex row with `flex-wrap`, sides `1fr` / center `2fr` so Collections and Schedule stay equal while To review is widest; columns wrap under each other when the window is too narrow; each column `overflow-y: auto`):

| Column | Frame / route | Behaviour |
|--------|-------------|-----------|
| Collections (left) | Lazy `turbo-frame#review_collections_frame` → `GET /review/collections` | Paginated list + combobox search; `collection--section-list-item` rows; drop → collect via `collect-drop` |
| To review (center) | Inline in `show` | Period/count as centered section description; `collection--date-divider` between `pops_on` groups; geared pagination; draggable bullets + bulk-menu |
| Schedule (right) | Lazy `turbo-frame#review_scheduled_frame` → `GET /review/scheduled` | 7 days forward from today (`Date.current..Date.current+6`); `.active` bullets per day; drop → postpone via `pops-drop` with `X-Requested-With: review-pops-drop` (optimistic append to end of day zone) |

Side partials: `reviews/_collections_side`, `reviews/_to_review`, `reviews/_calendar_side` / `_calendar_date`.

**Mobile** (`show.html+mobile.erb`): same three sections in a horizontal CSS scroll-snap track (`.review--spread-sections`, like monthlylog). Starts on To review (`review-mobile-sections` → `scrollToReview`). Triage on touch via bulk-menu (Later / Save / Archive / Complete). Drop handlers POST with optimistic client updates (append to end of drop zone / remove on collect). Pops drop uses `X-Requested-With: review-pops-drop` / `pops-drop`; pops controller returns `head :no_content` for drop requests.

## Logs (optional Future / Monthlylog, single Daylog + Pending)

Logs are **independent** buckets — no FK ownership between Future, Monthlylog, and Daylog. Controllers resolve “current” records with inline queries (`futures.covering(date)`, `monthlylogs.covering(date)`, `user.daylog`).

**Future** — optional six-month park (`period_from` month start; `period_to` auto end of month 6). `spread_months` still exists on the model for later month UI. Manual create: **`GET/POST /futures`**. **Show (temporary):** unplanned-only chat list (`pops_on` nil) with the shared chat composer (Task/Note) — month cards are hidden from the UI for now. Sometime → covering Future when one exists. No overlap checks between Futures.

**Monthlylog** — optional one calendar month (`period_from` / auto `period_to`). `spread_days` lists each day. **`GET /monthlylog`** → covering current month, or an empty placeholder with **`POST /monthlylogs`** → `Monthlylog.provision!` (current month + bucket; idempotent). No month-picker form. **`show`** is a calendar + isolated `chat--wrap` panes (dated / unplanned) with a page-level chat composer (`changeContext` on focus). Lazy frames via **`GET /monthlylogs/:id/bullets`**. Mobile tabbar links to current monthlylog. Styles in `monthlylog.css` (`monthlylog--*`), shared list chrome in `chat.css`.

**Daylog** — **one per user** (`has_one :daylog`), provisioned in `Onboarding#complete` alongside Loose Notes and Pending (via `Daylog.provision!`). Day slice is **`pops_on`**. **`GET /daylog`**: if missing (legacy / destroyed), `show` renders a create form (`POST /daylog` → `Daylog.provision!`); if present, lists that day’s bullets. Day-level mood/photo via **`Daylog::MoodEntity`** / **`Daylog::Picture`**. Call sites that need the daylog bucket read `user.daylog.bucket` (no lazy ensure). Create always requires an explicit `bucket_id`. Daylog name/icon constants live on `Onboarding` (`DAYLOG_NAME`, `DAYLOG_ICON`). When the triage inbox is non-empty, the daylog header chip links to **`GET /triage`** with a live count (`GET /triage/number`).

**Pending** — **one per user** (`has_one :pending`), provisioned in `Onboarding#complete` (and lazily via `Pending.provision!`). Holding pen for external captures (`pops_on` always nil). **`GET /triage`** (`TriageController#show`) lists the inbox: active Pending-bucket bullets **plus** active bullets in the current Monthlylog planned for today (`pops_on: Date.current`). Each triage row has **Today** (`POST /triage/bullets/:bullet_id/accept` → daylog via `postpone!`) and **Discard** (`POST /triage/bullets/:bullet_id/discard` → `archive!`); turbo-stream responses remove the triage row in place. Pending-bucket bullets are excluded from Review. Name/icon: `Onboarding::PENDING_NAME` / `PENDING_ICON`.

## Organizing from the timeline

Select bullets via the marker checkbox inlined in **`bullets/_bullet.html.erb`** (and monthly/future drag wrappers) — `bullet--marker` label over a screen-reader checkbox with `data-bulk-menu-target="checkbox"`. The sticky **`_bulk_menu`** (styled in `bulk-menu.css`, driven by `bulk-menu` Stimulus on the page wrapper) keeps selection in **`idListValue`** and syncs a comma-separated `bullet_ids` CSV into every `data-bulk-menu-target="idList"` hidden field.

**Direct intents (no UI fetch):** **pin**, **archive** — `POST`/`DELETE` with `turbo_stream` from menu forms.

**UI fetch then intent:** **Later** (postpone) and **Save** (collect) — `openPopsPicker` / `openCollectsPicker` set frame `src` with `bullet_ids` from `idListValue`, then `showPopover()` (lazy turbo-frame + popover, like pinned footer); picker POST/search forms use `data-bulk-menu-target="idList"` (synced on `idListTargetConnected` and `idListValueChanged`). Collect picker search reloads via GET with `q`; **create collection** link passes `bullet_ids` and `return_to` to `new_collection_path`. Menu embeds search via `searches/form` + `searches/palette` + combobox (`GET /search`, turbo-stream for live input); menu shell is `GET /menu`. ⌘J opens menu, ⌘K opens menu and focuses search. Lexxy `#` / `@` suggestions use `filter`.

**Postpone intent:** `POST /bullets/postpone` with required `bucket_id` and optional `pops_on`. Date options send Daylog + date; **This month** sends current Monthlylog when it exists (`pops_on` nil); **Sometime** sends covering Future when it exists (`pops_on` nil). Monthly/Future/review drops always pass an explicit `bucket_id`. **Collect intent:** `POST /bullets/collect` with `bucket_id` migrates into a collection (no uncollect). Pin/Unpin and complete/uncomplete hide based on selection state. Activity records `rescheduled`, `collected`, `completed`, `pinned`, and `unpinned` where applicable.

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

- **Rapid logging** uses the chat composer on daylog / collection / monthlylog / future (Lexxy `note` editor + type picker); edit is a body-only form
- **Daily focus** is explicit (`/daylog` and dated daylog paths show the daily log)
- **Migration over rewrite** happens where needed by editing or changing bullet type
- **Deferred decisions** are supported by moving `pops_on` forward (postpone) or tagging a project
- **Separation of concerns** mirrors BuJo pages: today/timeline, archived, pinned

## Projects (tags)

`Project` is a first-class model (`belongs_to :user`) with `name` and `colour`. Shared behaviour: `Colourable`, `Pinnable`, `ActionText::Attachable`. Mark is fixed (`#` → hash icon). Bullets link via `bullet_projects` (many-to-many). Surface: `GET /projects`. Lexxy `#` prompt (`lexxy-prompt` → `GET /projects/suggestions?filter=`) is mounted on the Note form and the chat composer. Pin/unpin uses `projects/pin` on the show page.

Projects link via `bullet_projects` (many-to-many). Body attachable sync (`sync_projects_from_body!`) runs for **every bulletable type**, triggered by the Action Text `body` after_save hook. Explicit add/remove intents are deferred to a future API.

## Buckets and memberships

`Bucket` belongs to a user and uses `delegated_type :bucketable` (`Collection`, `Future`, `Monthlylog`, `Daylog`, `Pending`). Every bullet has exactly one `bucket_id` (required).

| Type | Role | `pops_on` |
|------|------|-----------|
| Daylog | Daily rapid log (1 per user) | Required (day slice) |
| Monthlylog | Optional monthly spread | Day cell or nil |
| Future | Optional six-month park | nil = unplanned; month start in spread |
| Collection | Topical park | Always nil |
| Pending | External capture inbox (1 per user) | Always nil |

Bucket **identity** (`name`, `colour`, `icon`, optional `description`) lives on `buckets`. Collection names are unique per user. Home hub: `GET /home` (also **`root`**).

**Collection archive:** all bucket types are archivable (`Bucket#archive!` / `#unarchive!` via `Archivable`). `DELETE /collections/:id` soft-archives the bucket by inserting an `Archive` row; archived collections are hidden from home, review collect panel, and collect picker (`collections.merge(Bucket.active)`). Collect into an archived bucket is rejected (`Collectable` uses the `.active` scope, surfacing 404). Activity records `archived` / `unarchived` with subject `Archive`. Purge after retention is handled by `CleanSoftDeletedRecordsJob` (see Sweep Rules).

## Pinned workspace

Desktop footer has a single **Pinned** button (pin icon) in [`shared/_footer.html.erb`](app/views/shared/_footer.html.erb) ([`pinned/pinned_button`](app/views/pinned/_pinned_button.html.erb)). Clicking opens a lazy popover (`turbo-frame#pinned_list`) that loads a flat list of all pinned entities (Bullet, Bucket, Project) via [`pinned#index`](app/controllers/pinned_controller.rb) with `Turbo-Frame: pinned_list` (popover chrome + [`pinned/pinned_entity`](app/views/pinned/_pinned_entity.html.erb) rows live in that same template). Mobile uses the bottom tab bar via [`shared/_footer.html+mobile.erb`](app/views/shared/_footer.html+mobile.erb) and **`GET /pinned`** for the same flat list in full-page mode (with bulk menu for bullets). Pin/unpin Turbo Streams replace bullet rows (`render "bullets/bullet"`) and entity pin buttons only — the footer button is static.

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
GET    /monthlylog                      → monthlylogs#show (current)
GET    /futures/:id                  → futures#show
resources :monthlylogs                   → monthlylogs#create/show
  GET  /monthlylogs/:monthlylog_id/bullets → monthlylogs/bullets#index

# Bullets CRUD (no index — daily log is /daylog; no Drive /new)
GET    /bullets/:id                         → bullets#show
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
GET    /daylog/bullets?before=:id            → daylogs/bullets#index (older chat page, 204 when exhausted)
POST   /daylog/mood_entity                   → daylogs/mood_entities#create
DELETE /daylog/mood_entity                   → daylogs/mood_entities#destroy
GET    /daylog/picture                       → daylogs/pictures#show
POST   /daylog/picture                       → daylogs/pictures#create
DELETE /daylog/picture                       → daylogs/pictures#destroy

# Home & navigation
GET    /home                                 → home#show
GET    /home/activities                      → home/activities#index
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
| `button.css` | **Variants:** `button--primary`, `button--secondary`, `button--tertiary`, `button--accent`, `button--link`, `button--danger` (with `button--secondary`). **Shape:** `button--circle`. **Size:** `button--icon` / `icon-strong` / `icon-subtle`, `button--sm`, `button--lg`. **Width:** `button--wide` | Shared chrome for links and `<button>`; hover/active in `button.css` |
| `utilities.css` | `utilities--sr-only`, `utilities--line-clamp-1`, `utilities--text-sm`, `utilities--contents`, `utilities--handwriting` | Small cross-page helpers only; prefer component/layout classes when possible |
| `layout.css` | `layout--page`, `layout--column`, `layout--header`, `layout--header-actions`, `layout--list`, `layout--list-item`, `layout--main`, `header`, `footer`, `footer--dock` | Page structure and app shell chrome (`shared/_header`, `shared/_footer`; daylog and bucket pages use `layout--page`) |
| `bucket.css` | `bucket--list`, `bucket--list-item-link`, `bucket--list-item-marker`, … | Bucket list chrome and item styling (pair with `layout--list` / `layout--list-item`) |
| `dialog.css` | `dialog`, `dialog--large`, `dialog--header`, `dialog--body`, `dialog--footer` | Native `<dialog>` chrome (shared pickers, etc.) |
| `hotkey-hint.css` | `hotkey-hint`, `hotkey-hint--always` | Keyboard shortcut badges on buttons |
| `bullets-form.css` | `bullets-form`, `bullets-form--rail`, … | Body-only edit form chrome |
| `composer.css` | `composer`, `composer--rail`, `composer--field`, `composer--chrome`, `composer--multiline`, … | Fixed chat composer dock |
| `daylog.css` | `daylog--chat`, `daylog--shell`, `daylog--scroller`, `daylog--older-trigger`, `daylog--date-picker`, `daylog--mood`, `daylog--photo-card`, `daylog--photo-toolbar`, … | Chat shell and day-level artifacts on the daylog |
| `triage.css` | `triage--header`, `triage--list`, `triage--chip`, `triage--bullet`, … | Triage inbox page chrome and daylog chip |
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
