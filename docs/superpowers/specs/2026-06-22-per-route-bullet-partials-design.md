# Per-route bullet partials — remove parameterized bullet helpers

**Date:** 2026-06-22
**Status:** Approved
**Scope:** Refactor bullet rendering from a parameterized central partial (`bullets/_bullet.html.erb` with `draggable:`/`monthly_bucket:` flags + `render_bullet`/`render_bullet_compact`/`render_monthly_bucket_bullet` helpers) into route-specific `_bullet` partials assembled from shared component partials. Inline the monthly-bucket composer frame id/class helpers. Replace `bucket_palette_path` with route-specific `_bucket` partials. `ApplicationHelper` ends up empty.

No schema, model, or controller-action changes. View-only refactor plus helper removal.

## Context

`app/helpers/application_helper.rb` (33 lines) defines six methods:

| Method | Live call sites | Notes |
|---|---|---|
| `bucket_palette_path(bucket)` | 3 | `case bucket.bucketable when Collection/FutureBucket/MonthlyBucket` dispatch to route helpers + `raise` |
| `render_bullet(bullet, draggable:, monthly_bucket:)` | 6 direct + 5 indirect (via `bullets/_turbo_stream_update.html.erb` rendered from 5 turbo streams: pin/unpin/uncollect/complete/uncomplete) | Thin wrapper over `render 'bullets/bullet', ...` |
| `render_monthly_bucket_bullet(bullet)` | **0** | Dead. Calls `render_bullet(bullet, draggable: true, monthly_bucket: true)`; superseded by `monthly_buckets/bullets/_bullet.html.erb` rendered directly |
| `monthly_bucket_composer_frame_id(pops_on)` | 5 | `"composer_#{pops_on.to_date.iso8601}"` or `"composer_unplanned"` |
| `monthly_bucket_composer_frame_class(pops_on)` | 3 (always paired with `_frame_id`) | `"bullet_pops_on_#{pops_on}"` |
| `render_bullet_compact(bullet)` | 1 (`pinned/_bullets_list.html.erb:13`) | Thin wrapper over `render 'bullets/compact', ...` |

Two observations drive this refactor:

1. **The `monthly_bucket: true` branch in `bullets/_bullet.html.erb` is dead.** The only code path that passes `monthly_bucket: true` is the dead `render_monthly_bucket_bullet`. Live monthly-bucket bullets render through a separate, dedicated `monthly_buckets/bullets/_bullet.html.erb` that lives next to `MonthlyBuckets::BulletsController` and hardcodes its attributes. This is the per-route pattern, already applied once.
2. **The only live non-default flag is `draggable: true`, used by exactly one route** (`/review` desktop, via `reviews/_bullet_row.html.erb` ← `reviews/show.html.erb`). Every other `render_bullet` call passes defaults.

The current `bullets/_bullet.html.erb` carries two flags and three runtime branches to serve exactly two rendering contexts (default + review-desktop). The monthly context already fled to its own partial. We extend that pattern to the remaining contexts.

Separately, `bucket_palette_path` and the composer frame id/class helpers are view-glue that can either inline or move to route-specific partials. The user wants the latter for `bucket_palette_path` ("отдельный `_bucket` для каждого роута, там есть нюансы везде") and inlining for the composer helpers.

## Design

### Principles

1. **`bullets/` holds component partials only** — primitive pieces (`_marker`, `_body`, `_select`, `_metadata`, `_attachments`, `_monthly_bucket_line`) that take a `bullet:` local and render one chunk. No `<turbo-frame>` wrappers, no flags.
2. **Each route that renders a bullet owns its `_bullet.html.erb`** — a thin `<turbo-frame>` wrapper with hardcoded attributes for that route, assembled from `bullets/` components. No `draggable:`/`monthly_bucket:` locals.
3. **Route-specific `_bullet` variants are distinct files**, not flag branches. Review desktop's draggable bullet lives in `reviews/_bullet.html.erb`; the default non-draggable bullet lives in `bullets/_bullet.html.erb`.
4. **Compact is a route variant, not a separate concept.** `pinned/_bullet.html.erb` is the compact variant (today's `bullets/_compact.html.erb` renamed and relocated).
5. **Composer frame id/class inline** in the 5 monthly-bucket composer files. No helper.
6. **Route-specific `_bucket` partials** replace `bucket_palette_path`. Each route that links a bucket (`pinned`, `searches`) has its own `_bucket.html.erb` with the `case bucketable when ...` dispatch inlined for its own nuances.

### File changes

#### New: `app/views/bullets/_marker.html.erb`
The marker slot for non-monthly variants. Extracted from current `bullets/_bullet.html.erb:22-27` and the parallel block in `bullets/_compact.html.erb:17-22`.
```erb
<%# locals: (bullet:) %>
<% unless bullet.bulletable_type == "Title" %>
  <span class="bullet--marker <%= bullet.marker_styles %>" aria-hidden="true">
    <i class="icon" style="--icon-mask: var(--icon-<%= bullet.marker_icon %>)" aria-hidden="true"></i>
    <% if bullet.mood_marker.present? %>
      <span class="bullet--mood-emoji"><%= bullet.mood_marker %></span>
    <% end %>
  </span>
<% end %>
```

#### New: `app/views/bullets/_body.html.erb`
The `bullet--body` content for non-monthly, non-compact variants: Title `<h3>` OR name + attachments + metadata. Extracted from current `bullets/_bullet.html.erb:33-63` minus the monthly branch.
```erb
<%# locals: (bullet:) %>
<% if bullet.bulletable_type == "Title" %>
  <h3 class="bullet--title"><%= bullet.name %></h3>
<% else %>
  <% if bullet.body.to_plain_text.presence || bullet.rich_body? %>
    <div class="bullet--name">
      <% if bullet.bulletable_type == "Note" %>
        <%= link_to bullet.excerpt, bullet_path(bullet), data: { turbo_frame: "_top" } %>
      <% else %>
        <%= link_to bullet.body, bullet_path(bullet), data: { turbo_frame: "_top" } %>
      <% end %>
      <% if bullet.attachments.attached? %>
        <span class="pill" aria-label="Has attachments">
          <i class="icon" style="--icon-mask: var(--icon-paperclip)" aria-hidden="true"></i>
        </span>
      <% end %>
      <% if bullet.meta_labels.any? %>
        <span class="bullet--flags">
          <% bullet.meta_labels.each do |label| %>
            <span class="pill pill--<%= label[:colour] %>"><%= label[:emoji] %></span>
          <% end %>
        </span>
      <% end %>
    </div>
  <% end %>
  <%= render "bullets/attachments", bullet: bullet %>
  <%= render "bullets/metadata", bullet: bullet %>
<% end %>
```

#### Refactor: `app/views/bullets/_bullet.html.erb` (default, non-draggable)
Thin wrapper. Both flags and three branches removed.
```erb
<%# locals: (bullet:) %>
<turbo-frame id="<%= dom_id(bullet) %>"
             class="bullet"
             data-bullet-type="<%= bullet.bulletable_type.downcase %>"
             data-bullet-indented="<%= bullet.indented %>"
             <% if bullet.migrated? %>data-bullet-migrated<% end %>
             <% if bullet.completed? %>data-bullet-completed<% end %>>
  <div class="bullet--marker-slot">
    <%= render "bullets/marker", bullet: bullet %>
    <%= render "bullets/select", bullet: bullet %>
  </div>
  <div class="bullet--body">
    <%= render "bullets/body", bullet: bullet %>
  </div>
</turbo-frame>
```

#### New: `app/views/reviews/_bullet.html.erb` (draggable)
Route-specific draggable variant for `/review` desktop. Lives next to `ReviewsController`.
```erb
<%# locals: (bullet:) %>
<turbo-frame id="<%= dom_id(bullet) %>"
             class="bullet"
             data-bullet-type="<%= bullet.bulletable_type.downcase %>"
             data-bullet-indented="<%= bullet.indented %>"
             <% if bullet.migrated? %>data-bullet-migrated<% end %>
             <% if bullet.completed? %>data-bullet-completed<% end %>
             draggable="true"
             data-controller="bullet-drag"
             data-bullet-drag-id-value="<%= bullet.id %>"
             data-action="dragstart->bullet-drag#dragstart dragend->bullet-drag#dragend">
  <div class="bullet--marker-slot">
    <%= render "bullets/marker", bullet: bullet %>
    <%= render "bullets/select", bullet: bullet %>
  </div>
  <div class="bullet--body">
    <%= render "bullets/body", bullet: bullet %>
  </div>
</turbo-frame>
```

#### Existing: `app/views/monthly_buckets/bullets/_bullet.html.erb`
Unchanged. Already route-specific, already uses `_monthly_bucket_line`. It does not use `_marker`/`_body` because its marker is the monthly-bucket dot (no icon, no mood, no select checkbox) and its body is the monthly line. This is fine — it's the purest example of the pattern.

#### New: `app/views/pinned/_bullet.html.erb` (compact variant)
Rename of `app/views/bullets/_compact.html.erb`, relocated next to `PinnedController`. Uses `_marker` and `_select` from `bullets/`.
```erb
<%# locals: (bullet:) %>
<turbo-frame id="<%= dom_id(bullet) %>"
             class="bullet-compact bullet"
             data-bullet-type="<%= bullet.bulletable_type.downcase %>"
             <% if bullet.completed? %>data-bullet-completed<% end %>
             draggable="true"
             data-controller="bullet-drag"
             data-bullet-drag-id-value="<%= bullet.id %>"
             data-action="dragstart->bullet-drag#dragstart dragend->bullet-drag#dragend">
  <a href="<%= edit_bullet_path(bullet) %>"
     class="bullet-compact--link"
     draggable="false"
     data-turbo-frame="_top">
    <%= render "bullets/marker", bullet: bullet %>
    <span class="bullet-compact--name utilities--line-clamp-1<%= " bullet-compact--title" if bullet.bulletable_type == "Title" %>"><%= bullet.excerpt %></span>
    <% if bullet.meta_labels.any? %>
      <span class="bullet--flags">
        <% bullet.meta_labels.each do |label| %>
          <span class="pill pill--<%= label[:colour] %>"><%= label[:emoji] %></span>
        <% end %>
      </span>
    <% end %>
  </a>
  <%= render "bullets/select", bullet: bullet %>
</turbo-frame>
```
Note: `_marker` renders nothing for `Title` bullets (guarded internally), so the compact `<span class="bullet-compact--name ...">` always follows it — matches current `_compact.html.erb` behavior where the Title marker slot was skipped inline.

#### Delete: `app/views/bullets/_compact.html.erb`
Replaced by `pinned/_bullet.html.erb`.

#### Refactor: `app/views/reviews/_bullet_row.html.erb` → split by variant
Today: one file with `draggable:` and `row_actions:` locals, calling `render_bullet(bullet, draggable: draggable)`. The `draggable:` local is forwarded from `reviews/_inbox.html.erb` which is rendered with `draggable: true` (desktop) or `draggable: false` (mobile).

Replace with two variants:

**`app/views/reviews/_bullet_row.html.erb`** (desktop — default variant, `show.html.erb`):
```erb
<%# locals: (bullet:, row_actions:) %>
<div class="review--bullet-row">
  <%= render "reviews/bullet", bullet: bullet %>
  <% if row_actions %>
    <%= render "reviews/row_actions", bullet: bullet %>
  <% end %>
</div>
```

**`app/views/reviews/_bullet_row.html+mobile.erb`** (mobile — `show.html+mobile.erb`):
```erb
<%# locals: (bullet:, row_actions:) %>
<div class="review--bullet-row">
  <%= render "bullets/bullet", bullet: bullet %>
  <% if row_actions %>
    <%= render "reviews/row_actions", bullet: bullet %>
  <% end %>
</div>
```

`row_actions:` stays a local (it's a true boolean toggle for whether the row actions partial renders — a render-time decision, not a bullet-variant decision). `draggable:` disappears entirely.

**Update callers:**
- `reviews/_paginated_inbox.html.erb:4` — drop `draggable:` from the render call. It becomes `<%= render "reviews/bullet_row", bullet: bullet, row_actions: row_actions %>`. The `+mobile` variant is picked automatically by `request.variant`.
- `reviews/_inbox.html.erb:1,9` — drop `draggable:` from locals signature and from the render call. `_inbox` still passes `row_actions:`.
- `reviews/show.html.erb:8` — drop `draggable: true` from `render "reviews/inbox"`. Keep `row_actions: false`.
- `reviews/show.html+mobile.erb:6` — drop `draggable: false` from `render "reviews/inbox"`. Keep `row_actions: true`.

#### Inline composer frame id/class — 5 files in `monthly_buckets/bullets/`

Define the inline expression once per file at the top, then use it:
```erb
<% composer_id = pops_on.present? ? "composer_#{pops_on.to_date.iso8601}" : "composer_unplanned" %>
<% composer_class = "bullet_pops_on_#{pops_on}" %>
```

**`_composer_frame.html.erb`**:
```erb
<%# locals: (monthly_bucket:, pops_on: nil) %>
<% composer_id = pops_on.present? ? "composer_#{pops_on.to_date.iso8601}" : "composer_unplanned" %>
<turbo-frame id="<%= composer_id %>"
             class="bullet_pops_on_<%= pops_on %>"
             data-controller="composer-frame">
</turbo-frame>
```

**`_composer.html.erb`**: same id/class inline at top, used in `<turbo-frame id=... class=...>`.

**`_date_add.html.erb`**: already assigns `composer_frame_id` locally — replace the helper call with the inline ternary. No class needed here (it's a `<select>`, not a frame).

**`new.html.erb`**: already assigns `composer_frame_id` locally — replace helper call with inline ternary. Replace `monthly_bucket_composer_frame_class(@bullet.pops_on)` with inline `bullet_pops_on_<%= @bullet.pops_on %>`.

**`create.turbo_stream.erb`**: replace `monthly_bucket_composer_frame_id(@bullet.pops_on)` with inline ternary:
```erb
<% composer_id = params.dig(:bullet, :composer_id).presence || (@bullet.pops_on.present? ? "composer_#{@bullet.pops_on.to_date.iso8601}" : "composer_unplanned") %>
<%= turbo_stream.before(composer_id) do %>
  <%= render "monthly_buckets/bullets/bullet", bullet: @bullet %>
<% end %>
```

#### Inline `bucket_palette_path` into its 3 existing call sites

The 3 call sites already live in distinct route-specific files with their own class/content nuances. No new `_bucket` partials are needed — each file just inlines the `case bucket.bucketable when Collection/FutureBucket/MonthlyBucket` dispatch that `bucket_palette_path` currently centralizes:

```erb
<% path = case bucket.bucketable
        when Collection then collection_path(bucket.bucketable)
        when FutureBucket then future_path
        when MonthlyBucket then future_monthly_bucket_path(bucket.bucketable)
        else raise ArgumentError, "Unknown bucketable type: #{bucket.bucketable.class}"
        end %>
```

The 3 files:
- **`app/views/pinned/_bucket_footer_dock.html.erb:2`** — `link_to bucket_palette_path(bucket), class: ["pill", "pinned--summary", ...], data: { turbo_frame: "_top" } do ...` (marker + name block). Inline `path` at top of file, use in `link_to`.
- **`app/views/searches/_bucket.html.erb:2`** — `link_to bucket_palette_path(bucket), class: "bucket--list-item-link", data: { turbo_frame: "_top", combobox_target: "item", ... } do ...`. Inline `path` at top of file.
- **`app/views/pinned/index.html+mobile.erb:77`** — `link_to bucket.name, bucket_palette_path(bucket), class: "workspace__label", data: { turbo_frame: "_top" }`. This is inline in a `workspace__group-header`; inline `path` as a local at the top of the bucket loop (around line 69 where the loop starts).

The `case/when + raise` appears 3 times. Acceptable — new bucketable types are rare, and the `raise` surfaces misses immediately.

#### `app/helpers/application_helper.rb` — empty
After all moves, the module has no methods. Keep the file as an empty module (Rails autoloads it; removing it risks breaking the autoload path for no gain):
```ruby
# frozen_string_literal: true

module ApplicationHelper
end
```

#### Delete from `ApplicationHelper`
- `bucket_palette_path` (→ inlined into route-specific `_bucket` partials)
- `render_bullet` (→ direct `render "bullets/bullet", bullet: ...` or route-specific `_bullet`)
- `render_monthly_bucket_bullet` (dead)
- `render_bullet_compact` (→ `render "pinned/bullet", bullet: ...`)
- `monthly_bucket_composer_frame_id` (→ inline)
- `monthly_bucket_composer_frame_class` (→ inline)

#### Update all `render_bullet` / `render_bullet_compact` call sites
11 direct/indirect `render_bullet` calls + 1 `render_bullet_compact` call become direct `render "bullets/bullet", bullet: bullet` (or route-specific variant). See phase 3 for the full list.

#### Delete `app/views/bullets/_turbo_stream_update.html.erb`
Each of the 5 turbo streams (`bullets/pins/create.turbo_stream.erb`, `pins/destroy`, `collects/destroy`, `completes/create`, `completes/destroy`) inlines:
```erb
<%= turbo_stream.replace_all bullet do %>
  <%= render "bullets/bullet", bullet: bullet %>
<% end %>
```
The shared partial was a thin wrapper over `render_bullet`; with the helper gone, inlining the two lines per turbo stream is clearer than keeping an indirect partial.

### Turbo streams — cross-route re-render (deferred, see Out of scope)

`bullets/pins/*`, `bullets/completes/*`, `bullets/collects/destroy` turbo streams re-render the bullet via `bullets/_bullet` (non-draggable default). On `/review` desktop, a bullet that was draggable becomes non-draggable after pin/complete/uncollect — this is the existing behavior (the current `_turbo_stream_update` also calls `render_bullet` with defaults). Not a regression. Route-specific turbo streams for review/monthly are documented as a follow-up.

## Phases (each phase = one commit)

1. **Extract `bullets/_marker` + `bullets/_body`** from `_bullet.html.erb`. Refactor `bullets/_bullet.html.erb` to use them. Remove `monthly_bucket:` local and its three branches. `draggable:` local stays temporarily. All `render_bullet` call sites still work. → `bin/rails test` + `bin/rubocop` → commit.
2. **`reviews/_bullet.html.erb`** + split `_bullet_row` by `+mobile` variant. Update `_paginated_inbox`, `_inbox`, `show.html.erb`, `show.html+mobile.erb` to drop `draggable:`. Review now uses route-specific partial. → test + rubocop → commit.
3. **`pinned/_bullet.html.erb`** (rename from `bullets/_compact.html.erb`, use `_marker` + `_select`). Update `pinned/_bullets_list.html.erb:13` to `render "pinned/bullet", bullet: bullet`. Delete `bullets/_compact.html.erb`. Delete `render_bullet_compact` helper. → test + rubocop → commit.
4. **Inline `render_bullet` everywhere + delete helper.** Replace 6 direct + 5 indirect calls with `render "bullets/bullet", bullet: bullet`. Delete `_turbo_stream_update.html.erb`; inline its two lines into the 5 turbo streams. Delete `render_bullet` + `render_monthly_bucket_bullet` from `ApplicationHelper`. Remove `draggable:` local from `bullets/_bullet.html.erb` (no callers remain). → test + rubocop → commit.
5. **Inline composer frame id/class** in the 5 `monthly_buckets/bullets/` files. Delete `monthly_bucket_composer_frame_id` + `monthly_bucket_composer_frame_class` from `ApplicationHelper`. → test + rubocop → commit.
6. **Inline `bucket_palette_path`** into its 3 existing call sites (`pinned/_bucket_footer_dock.html.erb`, `searches/_bucket.html.erb`, `pinned/index.html+mobile.erb`). Each gets the `case/when + raise` dispatch inlined. Delete `bucket_palette_path` from `ApplicationHelper`. `ApplicationHelper` is now empty. → test + rubocop → commit.
7. **`bin/brakeman`** final security scan. → commit if any cleanup needed, else done.

## Verification

- `bin/rails test` after every phase
- `bin/rubocop` after every phase
- `bin/brakeman` at the end
- Manual smoke (after phase 6):
  - `/daylog` — default bullets render, `bullets/create.turbo_stream.erb` inserts before `.bullet_pops_on_<date>`
  - `/review` desktop — draggable bullets, pin/complete/uncollect re-render non-draggable (existing behavior)
  - `/review` mobile — non-draggable bullets with row actions
  - `/future/monthly_buckets/:id` — monthly-bucket bullets render via `monthly_buckets/bullets/_bullet`, composer frames get correct id/class, `create.turbo_stream.erb` inserts before composer
  - `/pinned` (mobile) — compact bullets, bucket links
  - `/pinned` desktop footer dock — bucket links
  - `/search?q=...` — bucket link in results
  - `/published/:code` — default bullets
  - Trigger pin/unpin/complete/uncomplete/uncollect on a bullet — turbo stream replaces the frame with `bullets/_bullet`

## Risks

1. **`+mobile` variant routing for `_bullet_row`.** Rails picks `_bullet_row.html+mobile.erb` when `request.variant == :mobile`. Confirmed: `ApplicationController#set_variant` at `app/controllers/application_controller.rb:24` sets `request.variant = :mobile` when the UA matches Mobile/Android/iPhone. Both variants will render correctly. If a future change drops `set_variant`, the default (`_bullet_row.html.erb`) renders for both — desktop gets draggable, mobile gets draggable too (regression). Guarded by the existing `set_variant` before_action.
2. **`_turbo_stream_update` removal.** 5 turbo streams gain 2 lines each. If a future bullet-variant needs a different re-render, each turbo stream must be updated individually — but that's the point (route context). The shared partial hid the variant question.
3. **`pinned/_bullet.html.erb` `_marker` for Title.** Current `_compact.html.erb` guards the marker with `unless bullet.bulletable_type == "Title"` inline. `_marker` has the same guard internally. Double-check the compact layout doesn't rely on the marker slot being absent (it doesn't — the `<a>` flows the same either way).
4. **Composer `create.turbo_stream.erb` fallback.** The `params[:bullet][:composer_id]` path is primary (passed from `new.html.erb` via `attributes: { composer_id: ... }`); the inline ternary is the fallback when `composer_id` wasn't submitted. Verify the fallback still matches the frame id format exactly (`composer_<iso8601>` / `composer_unplanned`).
5. **`bucket_palette_path` inline duplication.** The `case/when + raise` appears in 3 files. If a new `bucketable` type is added, each must be updated. Acceptable — new types are rare, and the `raise` surfaces misses immediately.

## Out of scope

- **Route-specific turbo streams for `/review` and `monthly_bucket`** on pin/complete/uncollect. Today `bullets/*` turbo streams re-render `bullets/_bullet` (non-draggable). Making `/review` re-render `reviews/_bullet` (draggable) and `/monthly_bucket` re-render `monthly_buckets/bullets/_bullet` requires either nested routes (`reviews/bullets/:id/pin`) or controller branching by request source. Documented as a follow-up; not in this refactor.
- **`TimelineHelper`** (4 date-nav methods) — separate topic, untouched.
- **`Bucket#palette_path` model method** — considered, rejected in favor of route partials per user preference.
- **Splitting `_bullet_row` further** by `row_actions:` — `row_actions` stays a local (true render-time toggle, not a variant).
- **Renaming `monthly_buckets/bullets/_bullet.html.erb`** — already route-specific, already correct, untouched.

## Why not other approaches

- **Keep `render_bullet` as the single render helper.** Rejected — the `monthly_bucket:` flag is dead, `draggable:` has one non-default caller, and the monthly route already proved the per-route pattern works. Keeping the helper preserves a parameterization that serves no live branching.
- **Move helpers to `BucketsHelper` / `MonthlyBuckets::BulletsHelper`.** Rejected for `bucket_palette_path` (route partials are more cohesive — each route owns its bucket-link nuances) and for composer id/class (inline is shorter than a helper call for a one-line ternary).
- **`Bucket#palette_path` on the model.** Rejected — view concern (route helpers), doesn't belong on the model.
- **Keep `bullets/_compact.html.erb` in `bullets/`.** Rejected — it's a pinned-specific variant; living in `pinned/` next to its only caller matches the pattern.
