# Timeline / Bullets feed split

## Goal

Split Daylog and filtered bullet feeds into two routes with distinct chrome, while sharing the same filter/timeline loading model. Rename the window shell from `chat--*` to `timeline--*` everywhere (including Search).

## Background

Today `BulletsController#index` + one `bullets/index.html.erb` serve Daylog, collections, and date filters via `@filter`, with branching for tabbar, collection header, and composer. The only real shared surface is the scrollable timeline window. `TimelinesControllerTest` already describes Daylog at `root`, but there is no `TimelinesController` yet — `root` points at `bullets#index`.

## Decisions

- **Daylog** lives on `TimelinesController#show` at `root`. Composer + primary tabbar. Empty filter only.
- **Filtered (and unfiltered) feeds** stay on `BulletsController#index` at `GET /bullets`. Query params unchanged (`collection`, `from`, `to`, `before`). Always filter chrome: back tabbar, header, **no composer**. Empty params still render current bullets (same empty `Bullet::Filter` as today), just without the composer.
- **No shared window partial** — the shell is small enough to duplicate in the two templates.
- **No new pagination concern** — keep `Bullet::Pageable` + `Timeline#last_page` / `#page_before`. Controllers stay thin; `FilterScoped` remains for `@filter` / `@timeline`.
- **Rename everywhere:** CSS `chat--*` → `timeline--*`, `chat.css` → `timeline.css`, Stimulus `chat-scroll` → `timeline-scroll`, Search shell included, tests/selectors updated.

## Design

### 1. Routes

```ruby
root "timelines#show"
# resources :bullets unchanged — index remains filter/feed + before pagination
```

Optional named route helper for clarity (`resource :timeline, only: :show` or `get "/", … as: :timeline`) is fine if it keeps `root` and gives a stable path helper for `data-timeline-scroll-path-value` on Daylog.

### 2. Controllers

**`TimelinesController#show`**
- `include FilterScoped`
- Always build an **empty** filter for Daylog (`Bullet::Filter.from_params({}, user: …)`), so stray query params on `root` do not change the feed; still allow `params[:before]` for pagination
- Load page like current index: `@bullets = @timeline.last_page` or older page when `params[:before]` present
- `before` HTML response continues to render `bullets/sections`

**`BulletsController#index`**
- Same `FilterScoped` + page load as today
- Renders filter chrome template regardless of whether `@filter.empty?`
- CRUD actions unchanged

Do **not** introduce a `TimelinePaged` concern unless the `before` response block is copy-pasted verbatim and becomes painful — YAGNI on top of `Pageable`.

### 3. Views

**`timelines/show.html.erb`**
- `shared/tabbar`
- `main.timeline--window` → scroller (`#timeline`) with `timeline-scroll`, path = Daylog route; sections with `mount_today: true` (composer append target — Daylog-only)
- composer dock
- `bullets/bulk_menu`

**`bullets/index.html.erb`**
- `shared/back_tabbar`
- header always: title `@filter.name`; dropdown with Export; Edit only when `@filter.collection`
- scroller id: `dom_id(@filter.collection)` when collection, else `"bullets"` (Daylog keeps `"#timeline"`)
- sections with `mount_today: false`
- no composer
- `bullets/bulk_menu`

**Tabbar:** Daylog active state and link target `TimelinesController` / `root_path` (or `timeline_path`), not `bullets`.

### 4. Rename: chat → timeline

| Before | After |
|---|---|
| `app/assets/stylesheets/chat.css` | `timeline.css` |
| `.chat--window`, `--scroller`, `--composer`, `--load-more-trigger`, `--header` | `.timeline--*` |
| `chat_scroll_controller.js` / `chat-scroll` | `timeline_scroll_controller.js` / `timeline-scroll` |
| comments / helpers mentioning “chat-style lists” | timeline wording where it refers to this shell |

Update: bullets index, timelines show, searches show, `base.css` comment, controller registration, system/controller assertions.

Existing `timeline--composer` / `timeline--section` names stay; they are content classes, not the window shell.

### 5. Tests

- Point Daylog assertions at `root_path` / timeline show (`TimelinesControllerTest`): composer present, tabbar, `mount_today` section, load-more behavior.
- Keep filter/collection/upcoming/export cases on `bullets_path`.
- Empty `GET /bullets`: success, bullets rendered, **no** composer dock.
- Collection chrome: header + Export + Edit; Upcoming/empty bullets index: header title without Edit.
- Rename selectors in controller/system tests.
- `before` pagination: Daylog against timeline route; filtered against `bullets_path(... before:)`.

## Out of scope

- Changing `Bullet::Filter` / `Timeline` query semantics
- REST `CollectionsController#show` or `/upcoming` path
- Multiple named timelines (controller exists for future headroom only)
- Composer on filtered feeds
- Redesigning Search beyond the shell class/controller rename

## Success criteria

- Daylog and filter feeds no longer share one branching template
- Same page-load model (`Filter` + `Timeline` + `Pageable`) on both routes
- No `chat--*` / `chat-scroll` left in app or tests
- Existing infinite-scroll and section-merge behavior still works on both feeds
