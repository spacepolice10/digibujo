# Drag-and-Drop Cards into Playlists — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users drag any card in the Timeline and drop it onto a playlist lane in the dock to add it to that playlist.

**Architecture:** Two Stimulus controllers communicate via the browser-native `dataTransfer` API — `card-drag` on each card stores the card ID on drag start; `playlist-drop` on each dock lane reads it on drop and POSTs to `playlist_cards#create`. The existing Turbo Stream response on that action re-renders the dock lane automatically. No new controller registration needed — `lazyLoadControllersFrom` picks up new controllers automatically.

**Tech Stack:** Stimulus, HTML5 Drag and Drop API, Rails Turbo Streams, Minitest

---

### Task 1: Write the failing tests

**Files:**
- Create: `test/controllers/cards_controller_test.rb`
- Modify: `test/controllers/pinned_controller_test.rb`
- Modify: `test/controllers/playlists/cards_controller_test.rb`

- [ ] **Step 1: Create `test/controllers/cards_controller_test.rb`**

```ruby
# frozen_string_literal: true

require "test_helper"

class CardsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "timeline cards have card-drag controller attributes" do
    draft = Draft.create!
    @user.cards.create!(cardable: draft, content: "Drag me")
    get cards_path
    assert_select ".card[data-controller~='card-drag']"
    assert_select ".card[data-card-drag-id-value]"
  end
end
```

- [ ] **Step 2: Add drop-target test to `test/controllers/pinned_controller_test.rb`**

Add inside the class, after the existing tests:

```ruby
test "dock playlist lanes have playlist-drop controller attributes" do
  @user.playlists.create!
  get pinned_index_path, headers: { "Turbo-Frame" => "pinned_panel" }
  assert_select "[data-controller~='playlist-drop']"
  assert_select "[data-playlist-drop-url-value]"
end
```

- [ ] **Step 3: Add turbo_stream+JSON test to `test/controllers/playlists/cards_controller_test.rb`**

Add inside the class, after the existing tests:

```ruby
test "create responds with turbo stream when called with JSON body" do
  post playlist_cards_path(@playlist),
       params: { card_id: @card.id }.to_json,
       headers: { "Content-Type" => "application/json", "Accept" => "text/vnd.turbo-stream.html" }
  assert_response :success
  assert_equal "text/vnd.turbo-stream.html", response.media_type
end
```

- [ ] **Step 4: Run the new tests — confirm the markup tests fail**

```bash
bin/rails test test/controllers/cards_controller_test.rb test/controllers/pinned_controller_test.rb test/controllers/playlists/cards_controller_test.rb
```

Expected output: the `card-drag` and `playlist-drop` markup tests **fail** (attributes not yet present). The turbo_stream+JSON test **passes** (the controller already handles this format — it's a regression guard).

---

### Task 2: Create `card_drag_controller.js`

**Files:**
- Create: `app/javascript/controllers/card_drag_controller.js`

- [ ] **Step 1: Create the controller**

```js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { id: String }

  dragstart(event) {
    event.dataTransfer.effectAllowed = "move"
    event.dataTransfer.setData("card-id", this.idValue)
    this.element.classList.add("dragging")
  }

  dragend() {
    this.element.classList.remove("dragging")
  }
}
```

---

### Task 3: Create `playlist_drop_controller.js`

**Files:**
- Create: `app/javascript/controllers/playlist_drop_controller.js`

- [ ] **Step 1: Create the controller**

```js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }

  dragover(event) {
    event.preventDefault()
    event.dataTransfer.dropEffect = "copy"
    this.element.classList.add("drag-over")
  }

  dragleave() {
    this.element.classList.remove("drag-over")
  }

  async drop(event) {
    event.preventDefault()
    this.element.classList.remove("drag-over")

    const cardId = event.dataTransfer.getData("card-id")
    if (!cardId) return

    const token = document.querySelector("meta[name='csrf-token']").content

    const response = await fetch(this.urlValue, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": token,
        "Accept": "text/vnd.turbo-stream.html"
      },
      body: JSON.stringify({ card_id: cardId })
    })

    if (response.ok) {
      const html = await response.text()
      Turbo.renderStreamMessage(html)
    }
  }
}
```

---

### Task 4: Update `_card.html.erb` with drag markup

**Files:**
- Modify: `app/views/cards/_card.html.erb`

- [ ] **Step 1: Add `draggable`, controller, and action to the outer div**

Change the opening div from:
```erb
<div id="<%= card_dom_id %>" class="card<%= " archived" if card.archived? %>" style="--i: <%= local_assigns[:index] || 0 %>"<%= " data-card-type=\"#{card.cardable_type.downcase}\"" unless card.draft? %>>
```

To:
```erb
<div id="<%= card_dom_id %>"
     class="card<%= " archived" if card.archived? %>"
     style="--i: <%= local_assigns[:index] || 0 %>"
     <%= " data-card-type=\"#{card.cardable_type.downcase}\"" unless card.draft? %>
     draggable="true"
     data-controller="card-drag"
     data-card-drag-id-value="<%= card.id %>"
     data-action="dragstart->card-drag#dragstart dragend->card-drag#dragend">
```

- [ ] **Step 2: Add `draggable="false"` to the `.card-body` anchor**

Change:
```erb
<a class="card-body"
   href="<%= card_path(card) %>"
   data-turbo-frame="_top">
```

To:
```erb
<a class="card-body"
   href="<%= card_path(card) %>"
   data-turbo-frame="_top"
   draggable="false">
```

---

### Task 5: Update `_dock_stack.html.erb` with drop markup

**Files:**
- Modify: `app/views/playlists/_dock_stack.html.erb`

- [ ] **Step 1: Add drop controller, URL value, `--lane-colour`, and action to the `<section>`**

Change:
```erb
<section id="<%= dom_id(playlist, :dock) %>" class="pinned-dock__lane pinned-dock__lane--active">
```

To:
```erb
<section id="<%= dom_id(playlist, :dock) %>"
         class="pinned-dock__lane pinned-dock__lane--active"
         style="--lane-colour: <%= playlist.colour_variable %>"
         data-controller="playlist-drop"
         data-playlist-drop-url-value="<%= playlist_cards_path(playlist) %>"
         data-action="dragover->playlist-drop#dragover dragleave->playlist-drop#dragleave drop->playlist-drop#drop">
```

---

### Task 6: Add CSS

**Files:**
- Modify: `app/assets/stylesheets/card.css`
- Modify: `app/assets/stylesheets/playlists.css`

- [ ] **Step 1: Add grab cursor and dragging state to `card.css`**

Inside the `.card { }` block in `card.css`, add after the `transition` line:

```css
cursor: grab;

&.dragging {
  cursor: grabbing;
}
```

- [ ] **Step 2: Add drag-over state to `playlists.css`**

Add after the existing `.dragging { }` rule at the bottom of the `@layer components` block in `playlists.css`:

```css
.pinned-dock__lane.drag-over {
  outline: 2px solid var(--lane-colour);
  box-shadow: 0 0 0 4px color-mix(in oklch, var(--lane-colour) 20%, transparent);
  border-radius: var(--radius-base);
}
```

---

### Task 7: Run tests and commit

- [ ] **Step 1: Run the targeted tests — all should pass now**

```bash
bin/rails test test/controllers/cards_controller_test.rb test/controllers/pinned_controller_test.rb test/controllers/playlists/cards_controller_test.rb
```

Expected: all 5 tests pass.

- [ ] **Step 2: Run the full test suite**

```bash
bin/rails test
```

Expected: all tests pass with no regressions.

- [ ] **Step 3: Commit**

```bash
git add \
  app/javascript/controllers/card_drag_controller.js \
  app/javascript/controllers/playlist_drop_controller.js \
  app/views/cards/_card.html.erb \
  app/views/playlists/_dock_stack.html.erb \
  app/assets/stylesheets/card.css \
  app/assets/stylesheets/playlists.css \
  test/controllers/cards_controller_test.rb \
  test/controllers/pinned_controller_test.rb \
  test/controllers/playlists/cards_controller_test.rb
git commit -m "Add drag-and-drop from Timeline cards to playlist dock lanes"
```
