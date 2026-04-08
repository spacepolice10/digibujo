# Mobile Navigation Restructure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure the mobile bottom tab bar from 4 generic tabs (Streams, Cards, Upcoming, Calendar) to 4 semantic sections (Index, Workspace, Drafts, Upcoming), and build a new Workspace page that shows pinned cards and playlists as vertical grouped lists.

**Architecture:** Reuse existing routes — the mobile layout gains new tab links, and `PinnedController` gains a layout declaration plus a new `.html+mobile.erb` variant for the Workspace page. Desktop dock behaviour is unchanged (served as a turbo-frame from the same route). CSS for the workspace groups is added to `main-layout.css`.

**Tech Stack:** Rails 8.1, ERB, Minitest (`ActionDispatch::IntegrationTest`), CSS custom properties, Turbo Rails, request variants (`:mobile`)

---

## File Map

| Action | File | Responsibility |
|--------|------|----------------|
| Modify | `app/controllers/pinned_controller.rb` | Add mobile/desktop layout selection |
| Create | `app/views/pinned/index.html+mobile.erb` | Workspace page: grouped pinned + playlists |
| Modify | `app/assets/stylesheets/main-layout.css` | Add `.workspace-*` CSS classes |
| Modify | `app/views/layouts/mobile.html.erb` | Replace tab bar with 4 new tabs |
| Create | `test/controllers/pinned_controller_test.rb` | Test workspace vs dock rendering |

---

## Task 1: Workspace View — PinnedController, Mobile Variant, and CSS

**Files:**
- Modify: `app/controllers/pinned_controller.rb`
- Create: `app/views/pinned/index.html+mobile.erb`
- Modify: `app/assets/stylesheets/main-layout.css`
- Create: `test/controllers/pinned_controller_test.rb`

- [ ] **Step 1: Write the failing tests**

Create `test/controllers/pinned_controller_test.rb`:

```ruby
# frozen_string_literal: true

require "test_helper"

class PinnedControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "index renders workspace on mobile (direct visit)" do
    get pinned_index_path, headers: { "User-Agent" => "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0)" }
    assert_response :success
    assert_select ".workspace"
  end

  test "index renders dock on desktop (turbo-frame request)" do
    get pinned_index_path, headers: { "Turbo-Frame" => "pinned_panel" }
    assert_response :success
    assert_select "turbo-frame#pinned_panel"
    assert_select ".workspace", count: 0
  end
end
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
bin/rails test test/controllers/pinned_controller_test.rb
```

Expected: both tests fail — `.workspace` not found, layout not yet set.

- [ ] **Step 3: Add layout declaration to PinnedController**

Edit `app/controllers/pinned_controller.rb`:

```ruby
class PinnedController < ApplicationController
  layout -> { request.variant.mobile? ? "mobile" : "main-layout" }

  def index
    @pinned_cards = Current.user.cards.includes(:tags).pinned.order(updated_at: :desc)
    @playlists = Current.user.playlists.includes(playlist_cards: { card: :tags }).order(created_at: :desc)
  end
end
```

- [ ] **Step 4: Create the mobile workspace view**

Create `app/views/pinned/index.html+mobile.erb`:

```erb
<section class="workspace">
  <% if @pinned_cards.any? %>
    <div class="workspace__section">
      <div class="workspace__group-header">
        <span class="workspace__bar" style="background: var(--color-fg-base)"></span>
        <i class="icon workspace__icon" style="--icon-mask: var(--icon-pin)" aria-hidden="true"></i>
        <span class="workspace__label">Pinned</span>
        <span class="workspace__count"><%= pluralize(@pinned_cards.count, "card") %></span>
      </div>
      <% @pinned_cards.each do |card| %>
        <%= render partial: "cards/card", locals: { card: card, dom_prefix: "workspace" } %>
      <% end %>
    </div>
  <% end %>

  <% @playlists.each do |playlist| %>
    <div class="workspace__section">
      <div class="workspace__group-header">
        <span class="workspace__bar" style="background: <%= playlist.colour_variable %>"></span>
        <i class="icon workspace__icon" style="--icon-mask: var(--icon-<%= playlist.icon %>)" aria-hidden="true"></i>
        <span class="workspace__label">Playlist</span>
        <span class="workspace__count"><%= pluralize(playlist.playlist_cards.size, "card") %></span>
      </div>
      <% playlist.playlist_cards.each do |pc| %>
        <%= render partial: "cards/card", locals: { card: pc.card, dom_prefix: "workspace_#{playlist.id}" } %>
      <% end %>
    </div>
  <% end %>

  <% if @pinned_cards.none? && @playlists.none? %>
    <p class="workspace__empty">Nothing pinned or collected yet.</p>
  <% end %>
</section>
```

Note: `playlist.playlist_cards.each` iterates the already-loaded association (included in the controller with `includes(playlist_cards: { card: :tags })`), avoiding N+1 queries.

- [ ] **Step 5: Add workspace CSS to main-layout.css**

Append to the end of the `@layer components` block in `app/assets/stylesheets/main-layout.css` (before the closing `}`):

```css
  /* Workspace (mobile pinned + playlists page) */
  .workspace {
    padding: var(--spacing-vertical) var(--spacing-horizontal-half);
    display: flex;
    flex-direction: column;
    gap: var(--spacing-vertical);
  }

  .workspace__section {
    display: flex;
    flex-direction: column;
    gap: var(--spacing-vertical-half);
  }

  .workspace__group-header {
    display: flex;
    align-items: center;
    gap: var(--spacing-horizontal-half);
    padding-block: var(--spacing-vertical-half);
    border-bottom: 1px solid var(--color-stroke-base);
  }

  .workspace__bar {
    width: 3px;
    height: 1.25rem;
    border-radius: 2px;
    flex-shrink: 0;
  }

  .workspace__icon {
    width: var(--icon-size-subtle);
    height: var(--icon-size-subtle);
    color: var(--color-fg-subtle);
    flex-shrink: 0;
  }

  .workspace__label {
    font-size: var(--font-size-subtle);
    font-weight: var(--font-weight-strong);
  }

  .workspace__count {
    font-size: var(--font-size-subtle);
    color: var(--color-fg-subtle);
    margin-left: auto;
  }

  .workspace__empty {
    padding: var(--spacing-vertical) var(--spacing-horizontal-half);
    color: var(--color-fg-subtle);
    font-size: var(--font-size-subtle);
    text-align: center;
  }
```

- [ ] **Step 6: Run tests to confirm they pass**

```bash
bin/rails test test/controllers/pinned_controller_test.rb
```

Expected: both tests pass.

- [ ] **Step 7: Run full test suite to confirm no regressions**

```bash
bin/rails test
```

Expected: all tests pass.

- [ ] **Step 8: Commit**

```bash
git add app/controllers/pinned_controller.rb \
        app/views/pinned/index.html+mobile.erb \
        app/assets/stylesheets/main-layout.css \
        test/controllers/pinned_controller_test.rb
git commit -m "Add Workspace mobile view to PinnedController with grouped pinned + playlist sections"
```

---

## Task 2: Update Mobile Tab Bar

**Files:**
- Modify: `app/views/layouts/mobile.html.erb`

- [ ] **Step 1: Write the failing test**

Add to `test/controllers/pinned_controller_test.rb` (append inside the class, before the final `end`):

```ruby
  test "mobile layout renders workspace tab link" do
    get pinned_index_path, headers: { "User-Agent" => "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0)" }
    assert_select "nav.tab-bar a[href='#{pinned_index_path}']"
  end

  test "mobile layout renders index tab link to streams" do
    get pinned_index_path, headers: { "User-Agent" => "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0)" }
    assert_select "nav.tab-bar a[href='#{streams_path}']"
  end

  test "mobile layout renders drafts tab link to cards" do
    get pinned_index_path, headers: { "User-Agent" => "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0)" }
    assert_select "nav.tab-bar a[href='#{cards_path}']"
  end

  test "mobile layout renders upcoming tab link" do
    get pinned_index_path, headers: { "User-Agent" => "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0)" }
    assert_select "nav.tab-bar a[href='#{upcoming_path}']"
  end
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
bin/rails test test/controllers/pinned_controller_test.rb
```

Expected: 4 new tests fail — tab links not yet updated.

- [ ] **Step 3: Update the mobile tab bar**

Replace the `<nav class="tab-bar">` block in `app/views/layouts/mobile.html.erb`:

```erb
    <nav class="tab-bar">
      <%= link_to streams_path, class: "tab-bar-item #{'tab-bar-item--active' if controller_name == 'streams'}", aria: { label: "Index" } do %>
        <i class="icon" style="--icon-mask: var(--icon-list)" aria-hidden="true"></i>
      <% end %>
      <%= link_to pinned_index_path, class: "tab-bar-item #{'tab-bar-item--active' if controller_name == 'pinned'}", aria: { label: "Workspace" } do %>
        <i class="icon" style="--icon-mask: var(--icon-pin)" aria-hidden="true"></i>
      <% end %>
      <%= link_to cards_path, class: "tab-bar-item #{'tab-bar-item--active' if controller_name == 'cards'}", aria: { label: "Drafts" } do %>
        <i class="icon" style="--icon-mask: var(--icon-pencil)" aria-hidden="true"></i>
      <% end %>
      <%= link_to upcoming_path, class: "tab-bar-item #{'tab-bar-item--active' if controller_name == 'upcoming'}", aria: { label: "Upcoming" } do %>
        <i class="icon" style="--icon-mask: var(--icon-calendar)" aria-hidden="true"></i>
      <% end %>
    </nav>
```

- [ ] **Step 4: Run tests to confirm they pass**

```bash
bin/rails test test/controllers/pinned_controller_test.rb
```

Expected: all 6 tests pass.

- [ ] **Step 5: Run full test suite**

```bash
bin/rails test
```

Expected: all tests pass.

- [ ] **Step 6: Commit**

```bash
git add app/views/layouts/mobile.html.erb \
        test/controllers/pinned_controller_test.rb
git commit -m "Restructure mobile tab bar: Index, Workspace, Drafts, Upcoming"
```

---

## Verification Checklist

After both tasks are committed:

1. Open the app on a real mobile device or browser DevTools mobile emulation
2. **Index tab** (`/streams`) — type grid (All Cards, Tasks, Notes…) + Filters list visible
3. **Workspace tab** (`/pinned`) — pinned cards group appears first; each playlist appears as a separate group with its color bar and icon; card count shown in each header
4. **Workspace empty state** — sign in with an account with no pinned cards and no playlists; confirm "Nothing pinned or collected yet." message appears
5. **Drafts tab** (`/cards`) — card timeline loads
6. **Upcoming tab** (`/upcoming`) — upcoming tasks loads
7. **Active tab highlight** — each tab shows the active state when on its page
8. **Desktop dock unchanged** — on a desktop browser, the `/pinned` page loads as a horizontal dock inside the main layout (not the workspace view)
9. **FAB** — `+ Card` button still renders and is tappable on all 4 tabs
10. **No N+1 queries** — check Rails log when viewing Workspace with multiple playlists; playlist cards should load in 1 query (via includes), not one per playlist
