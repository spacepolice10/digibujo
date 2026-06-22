# Per-Route Bullet Partials Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor bullet rendering from one parameterized `bullets/_bullet.html.erb` partial + three render helpers into route-specific `_bullet.html.erb` partials assembled from shared component partials, inlining composer frame id/class and `bucket_palette_path`, leaving `ApplicationHelper` empty.

**Architecture:** `bullets/` holds component primitives (`_marker`, `_body`, `_select`, `_metadata`, `_attachments`, `_monthly_bucket_line`). Each route that renders a bullet owns a thin `_bullet.html.erb` wrapper with hardcoded attributes (no flags). Composer frame id/class inline in `monthly_buckets/bullets/`. `bucket_palette_path` inlined into its 3 existing call sites. `ApplicationHelper` ends up empty.

**Tech Stack:** Rails 8.1.2, Ruby 3.4.8, ERB, Turbo Streams, Minitest, RuboCop (rubocop-rails-omakase).

**Spec:** `docs/superpowers/specs/2026-06-22-per-route-bullet-partials-design.md`

---

## File Structure

**New files:**
- `app/views/bullets/_marker.html.erb` — marker slot component (icon + mood), used by `bullets/_bullet`, `reviews/_bullet`, `pinned/_bullet`.
- `app/views/bullets/_body.html.erb` — body content component (Title h3 OR name+attachments+metadata), used by `bullets/_bullet`, `reviews/_bullet`.
- `app/views/reviews/_bullet.html.erb` — draggable bullet variant for `/review` desktop.
- `app/views/reviews/_bullet_row.html+mobile.erb` — mobile variant of review bullet row (non-draggable).

**Modified files:**
- `app/views/bullets/_bullet.html.erb` — thin wrapper, no flags, uses `_marker` + `_body`.
- `app/views/reviews/_bullet_row.html.erb` — desktop variant, renders `reviews/bullet`.
- `app/views/reviews/_paginated_inbox.html.erb` — drop `draggable:` local.
- `app/views/reviews/_inbox.html.erb` — drop `draggable:` local.
- `app/views/reviews/show.html.erb` — drop `draggable: true`.
- `app/views/reviews/show.html+mobile.erb` — drop `draggable: false`.
- `app/views/pinned/_bullet.html.erb` (renamed from `app/views/bullets/_compact.html.erb`) — uses `_marker` + `_select`.
- `app/views/pinned/_bullets_list.html.erb` — `render "pinned/bullet", bullet: bullet`.
- `app/views/pinned/_bucket_bullets_list.html.erb` — `render "bullets/bullet", bullet: bullet`.
- `app/views/pinned/index.html+mobile.erb` — 4× `render "bullets/bullet", bullet: bullet`; inline `bucket_palette_path`.
- `app/views/pinned/_bucket_footer_dock.html.erb` — inline `bucket_palette_path`.
- `app/views/searches/_bucket.html.erb` — inline `bucket_palette_path`.
- `app/views/bullets/pins/create.turbo_stream.erb` — inline `_turbo_stream_update` body.
- `app/views/bullets/pins/destroy.turbo_stream.erb` — inline `_turbo_stream_update` body.
- `app/views/bullets/collects/destroy.turbo_stream.erb` — inline `_turbo_stream_update` body.
- `app/views/bullets/completes/create.turbo_stream.erb` — inline `_turbo_stream_update` body.
- `app/views/bullets/completes/destroy.turbo_stream.erb` — inline `_turbo_stream_update` body.
- `app/views/monthly_buckets/bullets/_composer_frame.html.erb` — inline frame id/class.
- `app/views/monthly_buckets/bullets/_composer.html.erb` — inline frame id/class.
- `app/views/monthly_buckets/bullets/_date_add.html.erb` — inline frame id.
- `app/views/monthly_buckets/bullets/new.html.erb` — inline frame id/class.
- `app/views/monthly_buckets/bullets/create.turbo_stream.erb` — inline frame id fallback.
- `app/helpers/application_helper.rb` — empty module.

**Deleted files:**
- `app/views/bullets/_compact.html.erb` (renamed to `app/views/pinned/_bullet.html.erb`).
- `app/views/bullets/_turbo_stream_update.html.erb` (inlined into 5 turbo streams).

---

## Task 1: Extract `bullets/_marker` component

**Goal:** Pull the marker slot (icon + mood) out of `bullets/_bullet.html.erb` into a reusable component partial. No behavior change yet — `_bullet` still has its flags and branches, just delegates the marker to the new partial.

**Files:**
- Create: `app/views/bullets/_marker.html.erb`
- Modify: `app/views/bullets/_bullet.html.erb:16-32`

- [ ] **Step 1: Create `app/views/bullets/_marker.html.erb`**

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

- [ ] **Step 2: Update `app/views/bullets/_bullet.html.erb` marker slot to use the new component**

Replace lines 22-27 (the non-monthly marker `<span class="bullet--marker ...">` block inside the `else` branch) with a render call. The `monthly_bucket` branch (lines 17-20) stays as-is for now. The result of the marker-slot div (lines 16-32) becomes:

```erb
  <div class="bullet--marker-slot">
    <% if monthly_bucket %>
      <% unless bullet.bulletable_type == "Title" %>
        <span class="bullet--monthly-bucket-dot" aria-hidden="true"></span>
      <% end %>
    <% else %>
      <%= render "bullets/marker", bullet: bullet %>
    <% end %>
    <% unless monthly_bucket %>
      <%= render "bullets/select", bullet: bullet %>
    <% end %>
  </div>
```

- [ ] **Step 3: Run the bullet rendering tests**

Run: `bin/rails test test/controllers/bullets_controller_test.rb test/controllers/reviews_controller_test.rb test/controllers/daylogs_controller_test.rb`
Expected: all PASS. The marker renders identically via the new partial.

- [ ] **Step 4: Run rubocop**

Run: `bin/rubocop app/views/bullets/_marker.html.erb app/views/bullets/_bullet.html.erb`
Expected: no offenses.

- [ ] **Step 5: Commit**

```bash
git add app/views/bullets/_marker.html.erb app/views/bullets/_bullet.html.erb
git commit -m "Extract bullet marker into _marker component partial"
```

---

## Task 2: Extract `bullets/_body` component and remove dead `monthly_bucket:` branch

**Goal:** Pull the body content (Title h3 OR name+attachments+metadata) into `_body.html.erb`. Remove the dead `monthly_bucket:` branch from `_bullet.html.erb` (the only caller passing `monthly_bucket: true` is the already-dead `render_monthly_bucket_bullet`). Keep `draggable:` local temporarily (removed in Task 5).

**Files:**
- Create: `app/views/bullets/_body.html.erb`
- Modify: `app/views/bullets/_bullet.html.erb`

- [ ] **Step 1: Create `app/views/bullets/_body.html.erb`**

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

- [ ] **Step 2: Rewrite `app/views/bullets/_bullet.html.erb` — drop `monthly_bucket:` local and branches, use `_marker` + `_body`**

The full new content:

```erb
<%# locals: (bullet:, draggable: false) %>
<turbo-frame id="<%= dom_id(bullet) %>"
             class="bullet"
             data-bullet-type="<%= bullet.bulletable_type.downcase %>"
             data-bullet-indented="<%= bullet.indented %>"
             <% if bullet.migrated? %>data-bullet-migrated<% end %>
             <% if bullet.completed? %>
             data-bullet-completed
             <% end %>
             <% if draggable %>
             draggable="true"
             data-controller="bullet-drag"
             data-bullet-drag-id-value="<%= bullet.id %>"
             data-action="dragstart->bullet-drag#dragstart dragend->bullet-drag#dragend"
             <% end %>>
  <div class="bullet--marker-slot">
    <%= render "bullets/marker", bullet: bullet %>
    <%= render "bullets/select", bullet: bullet %>
  </div>
  <div class="bullet--body">
    <%= render "bullets/body", bullet: bullet %>
  </div>
</turbo-frame>
```

Note: `monthly_bucket:` local and all its branches (monthly-bucket-dot marker, `unless monthly_bucket` guard on select, `elsif monthly_bucket` body branch rendering `monthly_bucket_line`) are gone. The `draggable:` local stays — it's still used by `render_bullet(bullet, draggable: draggable)` in `reviews/_bullet_row.html.erb` until Task 5.

- [ ] **Step 3: Run the full bullet rendering test suite**

Run: `bin/rails test test/controllers/bullets_controller_test.rb test/controllers/reviews_controller_test.rb test/controllers/daylogs_controller_test.rb test/controllers/monthly_buckets_controller_test.rb test/controllers/pinned_controller_test.rb test/controllers/bullets/completes_controller_test.rb test/controllers/bullets/pins_controller_test.rb test/controllers/bullets/collects_controller_test.rb`
Expected: all PASS. The monthly-bucket show tests still pass because monthly-bucket bullets render via `monthly_buckets/bullets/_bullet.html.erb` (untouched), not via `bullets/_bullet`.

- [ ] **Step 4: Run rubocop**

Run: `bin/rubocop app/views/bullets/`
Expected: no offenses.

- [ ] **Step 5: Commit**

```bash
git add app/views/bullets/_body.html.erb app/views/bullets/_bullet.html.erb
git commit -m "Extract bullet body into _body component and drop dead monthly_bucket branch"
```

---

## Task 3: Add `reviews/_bullet.html.erb` (draggable variant) and split `_bullet_row` by variant

**Goal:** Create the route-specific draggable bullet partial for `/review` desktop. Split `reviews/_bullet_row` into a desktop variant (renders `reviews/bullet`) and a mobile variant (renders `bullets/bullet`). Drop the `draggable:` local everywhere in the review chain.

**Files:**
- Create: `app/views/reviews/_bullet.html.erb`
- Modify: `app/views/reviews/_bullet_row.html.erb`
- Create: `app/views/reviews/_bullet_row.html+mobile.erb`
- Modify: `app/views/reviews/_paginated_inbox.html.erb`
- Modify: `app/views/reviews/_inbox.html.erb`
- Modify: `app/views/reviews/show.html.erb`
- Modify: `app/views/reviews/show.html+mobile.erb`

- [ ] **Step 1: Create `app/views/reviews/_bullet.html.erb`**

```erb
<%# locals: (bullet:) %>
<turbo-frame id="<%= dom_id(bullet) %>"
             class="bullet"
             data-bullet-type="<%= bullet.bulletable_type.downcase %>"
             data-bullet-indented="<%= bullet.indented %>"
             <% if bullet.migrated? %>data-bullet-migrated<% end %>
             <% if bullet.completed? %>
             data-bullet-completed
             <% end %>
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

- [ ] **Step 2: Rewrite `app/views/reviews/_bullet_row.html.erb` as the desktop variant**

```erb
<%# locals: (bullet:, row_actions:) %>
<div class="review--bullet-row">
  <%= render "reviews/bullet", bullet: bullet %>
  <% if row_actions %>
    <%= render "reviews/row_actions", bullet: bullet %>
  <% end %>
</div>
```

Note: `draggable:` local is gone. `row_actions:` stays (true render-time toggle).

- [ ] **Step 3: Create `app/views/reviews/_bullet_row.html+mobile.erb`**

```erb
<%# locals: (bullet:, row_actions:) %>
<div class="review--bullet-row">
  <%= render "bullets/bullet", bullet: bullet %>
  <% if row_actions %>
    <%= render "reviews/row_actions", bullet: bullet %>
  <% end %>
</div>
```

This is the mobile variant — renders the non-draggable `bullets/_bullet`. Rails picks this file automatically when `request.variant == :mobile` (set by `ApplicationController#set_variant` for mobile UAs).

- [ ] **Step 4: Update `app/views/reviews/_paginated_inbox.html.erb` — drop `draggable:`**

```erb
<%# locals: (row_actions:) %>
<div id="paginated-records" class="records-list" data-controller="pagination">
  <% @page.records.each do |bullet| %>
    <%= render "reviews/bullet_row", bullet: bullet, row_actions: row_actions %>
  <% end %>
  <% unless @page.last? %>
    <% next_href = review_path(from: @review_from.iso8601, to: @review_to.iso8601, page: @page.next_param) %>
    <%= link_to next_href,
          class: "pagination-trigger",
          data: { pagination_target: "nextPageLink", preload: @page.first? } do %>
      <i class="icon icon--spin" style="--icon-mask: var(--icon-spinner)" aria-hidden="true"></i>
    <% end %>
  <% end %>
</div>
```

- [ ] **Step 5: Update `app/views/reviews/_inbox.html.erb` — drop `draggable:`**

```erb
<%# locals: (row_actions:) %>
<main class="review--inbox" aria-label="Review inbox">
  <header class="review--inbox-header">
    <h3 class="review--panel-title">Inbox</h3>
    <p class="review--panel-description utilities--text-sm">Timeline bullets for this period.</p>
  </header>

  <article class="layout--column bucket--list review--inbox-list" data-bulk-menu-target="list">
    <%= render "reviews/paginated_inbox", row_actions: row_actions %>
  </article>

</main>
```

- [ ] **Step 6: Update `app/views/reviews/show.html.erb` — drop `draggable: true`**

Change line 8 from:
```erb
    <%= render "reviews/inbox", draggable: true, row_actions: false %>
```
to:
```erb
    <%= render "reviews/inbox", row_actions: false %>
```

- [ ] **Step 7: Update `app/views/reviews/show.html+mobile.erb` — drop `draggable: false`**

Change line 6 from:
```erb
  <%= render "reviews/inbox", draggable: false, row_actions: true %>
```
to:
```erb
  <%= render "reviews/inbox", row_actions: true %>
```

- [ ] **Step 8: Run review tests — desktop and mobile**

Run: `bin/rails test test/controllers/reviews_controller_test.rb`
Expected: all PASS. Key assertions to verify:
- `show desktop renders three-column workspace` — `assert_select 'turbo-frame.bullet[draggable="true"]', minimum: 1` (draggable bullets present on desktop via `reviews/_bullet`)
- `show mobile renders inbox row actions without week strip` — `assert_select 'turbo-frame.bullet[draggable="true"]', count: 0` (non-draggable on mobile via `bullets/_bullet`), `assert_select '.review--row-actions', minimum: 1`

- [ ] **Step 9: Run rubocop**

Run: `bin/rubocop app/views/reviews/`
Expected: no offenses.

- [ ] **Step 10: Commit**

```bash
git add app/views/reviews/_bullet.html.erb app/views/reviews/_bullet_row.html.erb app/views/reviews/_bullet_row.html+mobile.erb app/views/reviews/_paginated_inbox.html.erb app/views/reviews/_inbox.html.erb app/views/reviews/show.html.erb app/views/reviews/show.html+mobile.erb
git commit -m "Add route-specific reviews/_bullet and split _bullet_row by variant"
```

---

## Task 4: Rename `bullets/_compact` to `pinned/_bullet` and delete `render_bullet_compact`

**Goal:** Move the compact bullet partial to `pinned/_bullet.html.erb` (route-specific), make it use the shared `_marker` and `_select` components, update its single caller, delete the `render_bullet_compact` helper.

**Files:**
- Create: `app/views/pinned/_bullet.html.erb`
- Delete: `app/views/bullets/_compact.html.erb`
- Modify: `app/views/pinned/_bullets_list.html.erb:13`
- Modify: `app/helpers/application_helper.rb` (remove `render_bullet_compact`)

- [ ] **Step 1: Create `app/views/pinned/_bullet.html.erb`**

This is the compact variant, using `_marker` and `_select` components:

```erb
<%# locals: (bullet:) %>
<turbo-frame id="<%= dom_id(bullet) %>"
             class="bullet-compact bullet"
             data-bullet-type="<%= bullet.bulletable_type.downcase %>"
             <% if bullet.completed? %>
             data-bullet-completed
             <% end %>
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

Note: `_marker` internally guards `unless bullet.bulletable_type == "Title"` — renders nothing for Titles. This matches the original `_compact.html.erb` behavior where the marker was guarded inline.

- [ ] **Step 2: Update `app/views/pinned/_bullets_list.html.erb:13`**

Change line 13 from:
```erb
      <%= render_bullet_compact(bullet) %>
```
to:
```erb
      <%= render "pinned/bullet", bullet: bullet %>
```

- [ ] **Step 3: Delete `app/views/bullets/_compact.html.erb`**

```bash
git rm app/views/bullets/_compact.html.erb
```

- [ ] **Step 4: Remove `render_bullet_compact` from `app/helpers/application_helper.rb`**

Delete lines 30-32 (the `render_bullet_compact` method):
```ruby
  def render_bullet_compact(bullet)
    render 'bullets/compact', bullet: bullet
  end
```

- [ ] **Step 5: Run pinned tests**

Run: `bin/rails test test/controllers/pinned_controller_test.rb`
Expected: all PASS. Key assertion: `pinned bullets popover loads bullets on request` — `assert_select '.bullet-compact', text: /Pinned bullet/, count: 1`.

- [ ] **Step 6: Run rubocop**

Run: `bin/rubocop app/views/pinned/_bullet.html.erb app/views/pinned/_bullets_list.html.erb app/helpers/application_helper.rb`
Expected: no offenses.

- [ ] **Step 7: Commit**

```bash
git add app/views/pinned/_bullet.html.erb app/views/pinned/_bullets_list.html.erb app/helpers/application_helper.rb
git commit -m "Move compact bullet to pinned/_bullet and delete render_bullet_compact helper"
```

(Note: `git rm` from step 3 is already staged for deletion.)

---

## Task 5: Inline all `render_bullet` calls, delete `_turbo_stream_update`, delete `render_bullet` and `render_monthly_bucket_bullet`, remove `draggable:` local

**Goal:** Replace every remaining `render_bullet(...)` call with direct `render "bullets/bullet", bullet: bullet`. Inline the `_turbo_stream_update` partial into its 5 turbo-stream callers and delete it. Delete `render_bullet` and `render_monthly_bucket_bullet` from `ApplicationHelper`. Remove the now-unused `draggable:` local from `bullets/_bullet.html.erb`.

**Files:**
- Modify: `app/views/pinned/_bucket_bullets_list.html.erb:28`
- Modify: `app/views/pinned/index.html+mobile.erb` (lines 15, 37, 59, 83)
- Modify: `app/views/reviews/_bullet_row.html.erb:3`
- Modify: `app/views/bullets/pins/create.turbo_stream.erb:7`
- Modify: `app/views/bullets/pins/destroy.turbo_stream.erb:7`
- Modify: `app/views/bullets/collects/destroy.turbo_stream.erb:7`
- Modify: `app/views/bullets/completes/create.turbo_stream.erb:7`
- Modify: `app/views/bullets/completes/destroy.turbo_stream.erb:7`
- Delete: `app/views/bullets/_turbo_stream_update.html.erb`
- Modify: `app/views/bullets/_bullet.html.erb` (drop `draggable:` local + branch)
- Modify: `app/helpers/application_helper.rb` (delete `render_bullet`, `render_monthly_bucket_bullet`)

- [ ] **Step 1: Update `app/views/pinned/_bucket_bullets_list.html.erb:28`**

Change line 28 from:
```erb
  <%= render_bullet(bullet) %>
```
to:
```erb
  <%= render "bullets/bullet", bullet: bullet %>
```

- [ ] **Step 2: Update `app/views/pinned/index.html+mobile.erb` — 4 call sites (lines 15, 37, 59, 83)**

Each of these lines:
```erb
        <%= render_bullet(bullet) %>
```
becomes:
```erb
        <%= render "bullets/bullet", bullet: bullet %>
```

All four are identical replacements. Use `replaceAll` or edit each one with surrounding context to disambiguate.

- [ ] **Step 3: Update `app/views/reviews/_bullet_row.html.erb:3`**

The desktop `_bullet_row` currently renders `reviews/bullet` (from Task 3). Verify it does NOT call `render_bullet` anymore. If Task 3 was applied correctly, this file already renders `reviews/bullet` directly. Confirm by reading the file — there should be no `render_bullet` call. If there is, replace with `<%= render "reviews/bullet", bullet: bullet %>`.

- [ ] **Step 4: Inline `_turbo_stream_update` into `app/views/bullets/pins/create.turbo_stream.erb`**

Replace line 7:
```erb
    <%= render partial: "bullets/turbo_stream_update", formats: :html, locals: { bullet: bullet } %>
```
with:
```erb
    <%= turbo_stream.replace_all bullet do %>
      <%= render "bullets/bullet", bullet: bullet %>
    <% end %>
```

The full file becomes:
```erb
<% if @failed_bullet&.errors&.any? %>
  <%= turbo_stream.update "toasts" do %>
    <%= render "shared/toasts", type: "errmsg", messages: @failed_bullet.errors.full_messages %>
  <% end %>
<% else %>
  <% @bullets.each do |bullet| %>
    <%= turbo_stream.replace_all bullet do %>
      <%= render "bullets/bullet", bullet: bullet %>
    <% end %>
  <% end %>

  <%= turbo_stream.update "pinned_bullets_dock",
        partial: "pinned/pinned_bullets_dock",
        locals: { bullets: pinned_bullets } %>
<% end %>
```

- [ ] **Step 5: Inline `_turbo_stream_update` into `app/views/bullets/pins/destroy.turbo_stream.erb`**

Same replacement as step 4. Line 7 becomes the inlined `turbo_stream.replace_all` block. The full file is identical to `pins/create.turbo_stream.erb` (both do the same thing).

- [ ] **Step 6: Inline `_turbo_stream_update` into `app/views/bullets/collects/destroy.turbo_stream.erb`**

Replace line 7:
```erb
    <%= render partial: "bullets/turbo_stream_update", formats: :html, locals: { bullet: bullet } %>
```
with:
```erb
    <%= turbo_stream.replace_all bullet do %>
      <%= render "bullets/bullet", bullet: bullet %>
    <% end %>
```

The full file becomes:
```erb
<% if @failed_bullet&.errors&.any? %>
  <%= turbo_stream.update "toasts" do %>
    <%= render "shared/toasts", type: "errmsg", messages: @failed_bullet.errors.full_messages %>
  <% end %>
<% else %>
  <% @bullets.each do |bullet| %>
    <%= turbo_stream.replace_all bullet do %>
      <%= render "bullets/bullet", bullet: bullet %>
    <% end %>
  <% end %>
<% end %>
```

- [ ] **Step 7: Inline `_turbo_stream_update` into `app/views/bullets/completes/create.turbo_stream.erb`**

Replace line 7 with the inlined block. The full file becomes:
```erb
<% if @error_message %>
  <%= turbo_stream.update "toasts" do %>
    <%= render "shared/toasts", type: "errmsg", messages: [@error_message] %>
  <% end %>
<% else %>
  <% @bullets.each do |bullet| %>
    <%= turbo_stream.replace_all bullet do %>
      <%= render "bullets/bullet", bullet: bullet %>
    <% end %>
  <% end %>
<% end %>
```

- [ ] **Step 8: Inline `_turbo_stream_update` into `app/views/bullets/completes/destroy.turbo_stream.erb`**

Same as step 7. The full file becomes identical to `completes/create.turbo_stream.erb`.

- [ ] **Step 9: Delete `app/views/bullets/_turbo_stream_update.html.erb`**

```bash
git rm app/views/bullets/_turbo_stream_update.html.erb
```

- [ ] **Step 10: Remove `draggable:` local and branch from `app/views/bullets/_bullet.html.erb`**

The full new content (no `draggable:` local, no draggable branch):

```erb
<%# locals: (bullet:) %>
<turbo-frame id="<%= dom_id(bullet) %>"
             class="bullet"
             data-bullet-type="<%= bullet.bulletable_type.downcase %>"
             data-bullet-indented="<%= bullet.indented %>"
             <% if bullet.migrated? %>data-bullet-migrated<% end %>
             <% if bullet.completed? %>
             data-bullet-completed
             <% end %>>
  <div class="bullet--marker-slot">
    <%= render "bullets/marker", bullet: bullet %>
    <%= render "bullets/select", bullet: bullet %>
  </div>
  <div class="bullet--body">
    <%= render "bullets/body", bullet: bullet %>
  </div>
</turbo-frame>
```

- [ ] **Step 11: Remove `render_bullet` and `render_monthly_bucket_bullet` from `app/helpers/application_helper.rb`**

Delete these methods (lines 14-20 in the current file):
```ruby
  def render_bullet(bullet, draggable: false, monthly_bucket: false)
    render 'bullets/bullet', bullet: bullet, draggable: draggable, monthly_bucket: monthly_bucket
  end

  def render_monthly_bucket_bullet(bullet)
    render_bullet(bullet, draggable: true, monthly_bucket: true)
  end
```

The file now has only `bucket_palette_path`, `monthly_bucket_composer_frame_id`, `monthly_bucket_composer_frame_class` (those are removed in Tasks 6-7).

- [ ] **Step 12: Verify no remaining `render_bullet` or `render_monthly_bucket_bullet` references**

Run: `rg "render_bullet\b|render_monthly_bucket_bullet|render_bullet_compact" app/`
Expected: no matches.

- [ ] **Step 13: Run the full test suite**

Run: `bin/rails test`
Expected: all PASS. Key areas:
- `test/controllers/bullets/completes_controller_test.rb` — `bulk create completes selected tasks via turbo stream` asserts `turbo-stream action="replace" targets="#bullet_<id>"` (the inlined `turbo_stream.replace_all bullet` produces this).
- `test/controllers/bullets/pins_controller_test.rb` — pin/unpin turbo streams.
- `test/controllers/reviews_controller_test.rb` — desktop draggable, mobile non-draggable.

- [ ] **Step 14: Run rubocop**

Run: `bin/rubocop app/views/bullets/ app/views/pinned/ app/views/reviews/ app/helpers/application_helper.rb`
Expected: no offenses.

- [ ] **Step 15: Commit**

```bash
git add app/views/bullets/ app/views/pinned/ app/views/reviews/ app/helpers/application_helper.rb
git commit -m "Inline render_bullet calls, delete _turbo_stream_update and render helpers"
```

---

## Task 6: Inline composer frame id/class helpers

**Goal:** Replace `monthly_bucket_composer_frame_id` and `monthly_bucket_composer_frame_class` calls with inline expressions in the 5 monthly-bucket composer files. Delete both helpers from `ApplicationHelper`.

**Files:**
- Modify: `app/views/monthly_buckets/bullets/_composer_frame.html.erb`
- Modify: `app/views/monthly_buckets/bullets/_composer.html.erb`
- Modify: `app/views/monthly_buckets/bullets/_date_add.html.erb`
- Modify: `app/views/monthly_buckets/bullets/new.html.erb`
- Modify: `app/views/monthly_buckets/bullets/create.turbo_stream.erb`
- Modify: `app/helpers/application_helper.rb`

**Inline expressions (used per-file as needed):**
- Frame id: `<% composer_id = pops_on.present? ? "composer_#{pops_on.to_date.iso8601}" : "composer_unplanned" %>`
- Frame class: `class="bullet_pops_on_<%= pops_on %>"` (inline in the `<turbo-frame>` attribute)

- [ ] **Step 1: Update `app/views/monthly_buckets/bullets/_composer_frame.html.erb`**

```erb
<%# locals: (monthly_bucket:, pops_on: nil) %>
<% composer_id = pops_on.present? ? "composer_#{pops_on.to_date.iso8601}" : "composer_unplanned" %>
<turbo-frame id="<%= composer_id %>"
             class="bullet_pops_on_<%= pops_on %>"
             data-controller="composer-frame">
</turbo-frame>
```

- [ ] **Step 2: Update `app/views/monthly_buckets/bullets/_composer.html.erb`**

```erb
<%# locals: (monthly_bucket:, pops_on: nil, label: "Add bullet") %>
<% composer_id = pops_on.present? ? "composer_#{pops_on.to_date.iso8601}" : "composer_unplanned" %>
<turbo-frame id="<%= composer_id %>"
             class="bullet_pops_on_<%= pops_on %>"
             data-controller="composer-frame">
  <div class="bullet-composer">
    <%= link_to new_future_monthly_bucket_bullet_path(monthly_bucket, pops_on: pops_on),
          class: "bullet-composer--add",
          data: { turbo_frame: "_self" },
          aria: { label: label } do %>
      <i class="icon" style="--icon-mask: var(--icon-plus)" aria-hidden="true"></i>
      <%= label %>
    <% end %>
  </div>
</turbo-frame>
```

- [ ] **Step 3: Update `app/views/monthly_buckets/bullets/_date_add.html.erb`**

Replace line 2 (`<% composer_frame_id = monthly_bucket_composer_frame_id(date) %>`) with:
```erb
<% composer_frame_id = date.present? ? "composer_#{date.to_date.iso8601}" : "composer_unplanned" %>
```

Note: `date` here is always present (it's a required local for this partial), so the ternary's `else` branch is defensive. The rest of the file is unchanged — `composer_frame_id` is used on line 8 in `data-monthly-bucket-date-add-frame-id-value`.

The full file:
```erb
<%# locals: (monthly_bucket:, date:) %>
<% composer_frame_id = date.present? ? "composer_#{date.to_date.iso8601}" : "composer_unplanned" %>
<% add_label = "Add to #{date.strftime('%B %-d')}" %>
<div class="monthly-bucket--date-add">
  <select id="<%= dom_id(monthly_bucket, "date_add_#{date}") %>"
          class="select-menu monthly-bucket--date-add-select"
          data-controller="monthly-bucket-date-add"
          data-monthly-bucket-date-add-frame-id-value="<%= composer_frame_id %>"
          data-monthly-bucket-date-add-new-url-value="<%= new_future_monthly_bucket_bullet_path(monthly_bucket) %>"
          data-monthly-bucket-date-add-pops-on-value="<%= date.iso8601 %>"
          data-action="change->monthly-bucket-date-add#pick"
          aria-label="<%= add_label %>">
    <button type="button" class="monthly-bucket--date-add-button">
      <i class="icon" style="--icon-mask: var(--icon-plus)" aria-hidden="true"></i>
    </button>
    <option value="" disabled selected>Add…</option>
    <option value="Task">
      <%= render "shared/option_item",
            label: "Add task",
            hint: "Action you can complete",
            icon: "square",
            modifier: "task" %>
    </option>
    <option value="Event">
      <%= render "shared/option_item",
            label: "Add event",
            hint: "Scheduled occurrence",
            icon: "circle",
            modifier: "event" %>
    </option>
  </select>
</div>
```

- [ ] **Step 4: Update `app/views/monthly_buckets/bullets/new.html.erb`**

```erb
<% composer_frame_id = @bullet.pops_on.present? ? "composer_#{@bullet.pops_on.to_date.iso8601}" : "composer_unplanned" %>
<turbo-frame id="<%= composer_frame_id %>"
             class="bullet_pops_on_<%= @bullet.pops_on %>"
             data-controller="composer-frame">
  <%= render "bullets/bulletable_form",
        bullet: @bullet,
        url: future_monthly_bucket_bullets_path(@monthly_bucket),
        attributes: {
          pops_on: @bullet.pops_on,
          bucket_id: @bullet.bucket_id,
          composer_id: composer_frame_id
        }.compact %>
</turbo-frame>
```

- [ ] **Step 5: Update `app/views/monthly_buckets/bullets/create.turbo_stream.erb`**

```erb
<% composer_id = params.dig(:bullet, :composer_id).presence || (@bullet.pops_on.present? ? "composer_#{@bullet.pops_on.to_date.iso8601}" : "composer_unplanned") %>
<%= turbo_stream.before(composer_id) do %>
  <%= render "monthly_buckets/bullets/bullet", bullet: @bullet %>
<% end %>
```

- [ ] **Step 6: Delete `monthly_bucket_composer_frame_id` and `monthly_bucket_composer_frame_class` from `app/helpers/application_helper.rb`**

Delete these methods:
```ruby
  def monthly_bucket_composer_frame_id(pops_on)
    pops_on.present? ? "composer_#{pops_on.to_date.iso8601}" : "composer_unplanned"
  end

  def monthly_bucket_composer_frame_class(pops_on)
    "bullet_pops_on_#{pops_on}"
  end
```

- [ ] **Step 7: Verify no remaining references to the composer helpers**

Run: `rg "monthly_bucket_composer_frame_id|monthly_bucket_composer_frame_class" app/`
Expected: no matches.

- [ ] **Step 8: Run monthly bucket tests**

Run: `bin/rails test test/controllers/monthly_buckets_controller_test.rb test/controllers/monthly_buckets/bullets_controller_test.rb`
Expected: all PASS. Key assertions:
- `monthly_buckets_controller_test.rb:74` — `assert_select "turbo-frame#composer_#{day.iso8601}"` (frame id format unchanged).
- `monthly_buckets/bullets_controller_test.rb:15-19` — `composer_unplanned` frame id.
- `monthly_buckets/bullets_controller_test.rb:24,30-31` — `composer_#{day.iso8601}` frame id.

- [ ] **Step 9: Run rubocop**

Run: `bin/rubocop app/views/monthly_buckets/bullets/ app/helpers/application_helper.rb`
Expected: no offenses.

- [ ] **Step 10: Commit**

```bash
git add app/views/monthly_buckets/bullets/ app/helpers/application_helper.rb
git commit -m "Inline monthly bucket composer frame id/class helpers"
```

---

## Task 7: Inline `bucket_palette_path` and empty `ApplicationHelper`

**Goal:** Replace the 3 `bucket_palette_path` call sites with inlined `case/when` dispatch. Delete `bucket_palette_path` from `ApplicationHelper`. The module is now empty.

**Files:**
- Modify: `app/views/pinned/_bucket_footer_dock.html.erb`
- Modify: `app/views/searches/_bucket.html.erb`
- Modify: `app/views/pinned/index.html+mobile.erb`
- Modify: `app/helpers/application_helper.rb`

**Inline dispatch expression (used in each file):**
```erb
<% path = case bucket.bucketable
        when Collection then collection_path(bucket.bucketable)
        when FutureBucket then future_path
        when MonthlyBucket then future_monthly_bucket_path(bucket.bucketable)
        else raise ArgumentError, "Unknown bucketable type: #{bucket.bucketable.class}"
        end %>
```

- [ ] **Step 1: Update `app/views/pinned/_bucket_footer_dock.html.erb`**

Add the `path` local at the top, replace `bucket_palette_path(bucket)` in the `link_to`:

```erb
<% path = case bucket.bucketable
        when Collection then collection_path(bucket.bucketable)
        when FutureBucket then future_path
        when MonthlyBucket then future_monthly_bucket_path(bucket.bucketable)
        else raise ArgumentError, "Unknown bucketable type: #{bucket.bucketable.class}"
        end %>
<div class="pinned--dock">
  <%= link_to path,
        class: ["pill", "pinned--summary", "pinned--bucket-summary", bucket.colour.present? ? "pill--#{bucket.colour}" : nil].compact.join(" "),
        data: { turbo_frame: "_top" } do %>
    <span class="bucket--list-item-marker" data-bucket-colour="<%= bucket.colour %>" aria-hidden="true">
      <% if bucket.icon_path %>
        <%= image_tag bucket.icon_path, alt: "", class: "form--list-icon" %>
      <% elsif bucket.icon.present? %>
        <i
          class="icon"
          style="--icon-mask: <%= bucket.icon_mask %>"
          aria-hidden="true"
        ></i>
      <% end %>
    </span>
    <span class="utilities--line-clamp-1"><%= bucket.name %></span>
  <% end %>
</div>
```

- [ ] **Step 2: Update `app/views/searches/_bucket.html.erb`**

```erb
<% path = case bucket.bucketable
        when Collection then collection_path(bucket.bucketable)
        when FutureBucket then future_path
        when MonthlyBucket then future_monthly_bucket_path(bucket.bucketable)
        else raise ArgumentError, "Unknown bucketable type: #{bucket.bucketable.class}"
        end %>
<li class="layout--list-item" role="option">
  <%= link_to path,
        class: "bucket--list-item-link",
        data: {
          turbo_frame: "_top",
          combobox_target: "item",
          action: "click->search#rememberSelection",
          searchable_type: "Bucket",
          searchable_id: bucket.id
        } do %>
    <div class="bucket--list-item-name">
      <div class="bucket--list-item-marker" data-bucket-colour="<%= bucket.colour %>" aria-hidden="true">
        <% if bucket.icon_path %>
          <%= image_tag bucket.icon_path, alt: "", class: "form--list-icon" %>
        <% elsif bucket.icon.present? %>
          <i class="icon" style="--icon-mask: <%= bucket.icon_mask %>" aria-hidden="true"></i>
        <% end %>
      </div>
      <span class="utilities--line-clamp-1"><%= bucket.name %></span>
    </div>
  <% end %>
</li>
```

- [ ] **Step 3: Update `app/views/pinned/index.html+mobile.erb` — bucket loop (around line 64-86)**

In the bucket loop (starts at line 64 `<% @buckets.each do |pe| %>`), add the `path` local after `bucket` is assigned (after line 65 `<% bucket = pe.pinnable %>`) and before the `link_to` (line 76-79). Replace `bucket_palette_path(bucket)` in the `link_to`.

The loop becomes:
```erb
  <% @buckets.each do |pe| %>
    <% bucket = pe.pinnable %>
    <% next unless bucket %>
    <% bucket_bullets = Current.user.bullets.where(bucket_id: bucket.id).includes(bucket: :bucketable).order(updated_at: :desc) %>
    <% next if bucket_bullets.none? %>
    <% path = case bucket.bucketable
            when Collection then collection_path(bucket.bucketable)
            when FutureBucket then future_path
            when MonthlyBucket then future_monthly_bucket_path(bucket.bucketable)
            else raise ArgumentError, "Unknown bucketable type: #{bucket.bucketable.class}"
            end %>

    <div class="workspace__section">
      <div class="workspace__group-header">
        <span class="workspace__bar" data-bucket-colour="<%= bucket.colour %>" aria-hidden="true"></span>
        <% if bucket.icon.present? %>
          <i class="icon workspace__icon" style="--icon-mask: <%= bucket.icon_mask %>" aria-hidden="true"></i>
        <% end %>
        <%= link_to bucket.name,
              path,
              class: "workspace__label",
              data: { turbo_frame: "_top" } %>
        <span class="workspace__count"><%= pluralize(bucket_bullets.count, "bullet") %></span>
      </div>
      <% bucket_bullets.each do |bullet| %>
        <%= render "bullets/bullet", bullet: bullet %>
      <% end %>
    </div>
  <% end %>
```

Note: this loop also contains one of the `render_bullet` → `render "bullets/bullet"` replacements from Task 5. If Task 5 was applied, the `render_bullet(bullet)` on line 83 is already `render "bullets/bullet", bullet: bullet`. If not, apply that replacement here too.

- [ ] **Step 4: Delete `bucket_palette_path` from `app/helpers/application_helper.rb`**

Delete the method (lines 4-12 in the original file):
```ruby
  def bucket_palette_path(bucket)
    bucketable = bucket.bucketable
    case bucketable
    when Collection then collection_path(bucketable)
    when FutureBucket then future_path
    when MonthlyBucket then future_monthly_bucket_path(bucketable)
    else raise ArgumentError, "Unknown bucketable type: #{bucketable.class}"
    end
  end
```

The file now becomes:
```ruby
# frozen_string_literal: true

module ApplicationHelper
end
```

- [ ] **Step 5: Verify no remaining references to `bucket_palette_path`**

Run: `rg "bucket_palette_path" app/`
Expected: no matches.

- [ ] **Step 6: Run the full test suite**

Run: `bin/rails test`
Expected: all PASS. Key areas:
- `test/controllers/pinned_controller_test.rb` — pinned workspace, bucket links.
- `test/controllers/searches_controller_test.rb` — search results with bucket links.
- `test/controllers/buckets_controller_test.rb` — bucket show.

- [ ] **Step 7: Run rubocop**

Run: `bin/rubocop app/views/pinned/ app/views/searches/ app/helpers/application_helper.rb`
Expected: no offenses.

- [ ] **Step 8: Run brakeman**

Run: `bin/brakeman`
Expected: no new warnings. The inlined `case/when + raise` is not a security concern.

- [ ] **Step 9: Commit**

```bash
git add app/views/pinned/_bucket_footer_dock.html.erb app/views/searches/_bucket.html.erb app/views/pinned/index.html+mobile.erb app/helpers/application_helper.rb
git commit -m "Inline bucket_palette_path and empty ApplicationHelper"
```

---

## Task 8: Final verification and smoke check

**Goal:** Confirm the full refactor is coherent — all tests pass, no orphaned references, no dead code left behind.

- [ ] **Step 1: Verify no orphaned helper references**

Run: `rg "render_bullet\b|render_bullet_compact|render_monthly_bucket_bullet|bucket_palette_path|monthly_bucket_composer_frame_id|monthly_bucket_composer_frame_class" app/ test/`
Expected: no matches.

- [ ] **Step 2: Verify no orphaned partial references**

Run: `rg "bullets/compact|bullets/turbo_stream_update" app/`
Expected: no matches.

- [ ] **Step 3: Verify `ApplicationHelper` is empty**

Run: `rg -A 2 "module ApplicationHelper" app/helpers/application_helper.rb`
Expected:
```
module ApplicationHelper
end
```

- [ ] **Step 4: Run the full test suite**

Run: `bin/rails test`
Expected: all PASS.

- [ ] **Step 5: Run full rubocop**

Run: `bin/rubocop`
Expected: no offenses.

- [ ] **Step 6: Run brakeman**

Run: `bin/brakeman`
Expected: no new warnings.

- [ ] **Step 7: Manual smoke check (optional, if dev server available)**

Start `bin/dev` and verify these pages render correctly:
- `/daylog` — default bullets, no draggable attribute on `<turbo-frame class="bullet">`.
- `/review` (desktop) — bullets have `draggable="true"` and `data-controller="bullet-drag"`.
- `/review` (mobile UA) — bullets are non-draggable, row actions present.
- `/future/monthly_buckets/:id` — monthly-bucket bullets render with monthly-bucket-dot marker, composer frames have correct `id="composer_<date>"` and `class="bullet_pops_on_<date>"`.
- `/pinned` (mobile) — compact bullets, bucket links work.
- `/search?q=<bucket_name>` — bucket link in results works.
- Trigger pin on a bullet from `/review` desktop — turbo stream replaces the bullet frame. The re-rendered bullet is non-draggable (existing behavior, `bullets/_bullet` default).

---

## Notes for the implementer

- **ERB comment syntax:** `<%# locals: (bullet:) %>` on line 1 of each partial documents the required locals. Keep this convention.
- **`request.variant :mobile`** is set by `ApplicationController#set_variant` (`app/controllers/application_controller.rb:24`) based on User-Agent. The `+mobile` variant suffix on `_bullet_row.html+mobile.erb` is picked up automatically — no controller change needed.
- **`render @bullet` / `render @bullets` / `render page.records`** (in `published/index.html.erb`, `pagination/_paginated_records.html.erb`, `bullets/create.turbo_stream.erb`) use Rails model-convention rendering, which resolves to `bullets/_bullet.html.erb`. These still work after the refactor — `bullets/_bullet` remains the default partial for `Bullet`. No changes needed to those call sites.
- **`futures/show.html.erb:23`** — `render partial: "bullets/bullet", collection: unplanned, as: :bullet` — still works, no flags needed. No change.
- **The `monthly_buckets/bullets/_bullet.html.erb` partial is untouched.** It's already route-specific and uses `_monthly_bucket_line`, not `_marker`/`_body`. This is the purest example of the pattern we're extending.
- **Commit after each task** (per AGENTS.md "Large phased changes" rule). Each task is a self-contained, reviewable unit.
- **Tests are only edited if the behavior they cover changed.** The refactor preserves all behavior — existing tests should pass without modification. If a test fails, investigate the cause before changing the test.
