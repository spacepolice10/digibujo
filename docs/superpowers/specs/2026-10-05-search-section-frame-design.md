# Search section turbo-frame (live results) — design

**Date:** 2026-10-05  
**Status:** Approved

## Goal

Wrap search-navigation (and later live results) in `turbo-frame#search_section`. Typing in the dock loads `/search?q=…` into that frame; emptying the field loads `/search` and restores search-navigation. Results use full bullet rows and collection chips.

Builds on the composer-style dock in [`2026-10-05-search-form-design.md`](2026-10-05-search-form-design.md). Naming: **search-navigation** (not hub), **section** (not panel), **cleanup** (not clear).

## Decisions

| Decision | Choice |
| --- | --- |
| Frame id | `search_section` |
| Empty state | `searches/_navigation` (shortcuts + collection chips) |
| Clear empty field | Frame GET `/search` (no `q`) re-renders navigation |
| Query present | Frame GET `/search?q=…` renders `searches/_results` |
| Results markup | Full `bullets/bullet` rows + collection chips |
| Title (`h1`) | Outside the frame (does not flash on replace) |
| Debounce | ~80ms (same default as combobox) |
| Cleanup control | Class `.search--cleanup`; Stimulus action `search#cleanup` |

## Page structure (`searches/show.html.erb`)

```erb
<main class="chat--window search--window">
  <div class="chat--scroller search--scroller">
    <h1>Search</h1>

    <%= turbo_frame_tag "search_section" do %>
      <% if @q.present? %>
        <%= render "results", entries: @entries %>
      <% else %>
        <%= render "navigation" %>
      <% end %>
    <% end %>
  </div>

  <div id="search_dock" class="chat--composer search--dock">
    <%= render "searches/form" %>
  </div>
</main>
```

Frame-only responses render the same `turbo_frame_tag "search_section"` wrapper with either navigation or results (no full layout chrome beyond what Turbo expects). Prefer a single `show` template that works for both full page and frame requests (frame request still returns the matching frame id).

## Partials

### `searches/_navigation.html.erb`

Move current `#search_navigation` article + `#search_collections` grid here unchanged (same links, counters, chips).

### `searches/_results.html.erb`

Locals: `entries:` (array of Bullet / Collection from `Search::GlobalRequest`).

```erb
<div class="search--results">
  <% entries.each do |entry| %>
    <% if entry.is_a?(Bullet) %>
      <%= render partial: entry.to_partial_path, locals: { bullet: entry } %>
    <% else %>
      <%= link_to bullets_path(collection: entry.name),
            class: "collection-chip",
            data: { turbo_frame: "_top" } do %>
        <%= icon("hash", style: ("color: #{colour(entry.colour)};" if entry.colour.present?)) %>
        <span><%= entry.name %></span>
      <% end %>
    <% end %>
  <% end %>

  <% if entries.empty? %>
    <p class="search--results-empty">No results</p>
  <% end %>
</div>
```

Bullet partials nest their own `turbo-frame`; that is fine inside `search_section`. Result links that leave Search use `turbo_frame: "_top"`.

## Form + Stimulus

### Markup renames

- `search--clear-button` → `search--cleanup`
- `data-action="search#clear"` → `data-action="search#cleanup"`
- `aria-label="Clear search"` → `aria-label="Clean up search"` (or keep user-facing “Clear search” if preferred — **use “Clear search”** for a11y copy; class/method stay `cleanup`)

Add:

- `data-search-target="section"` on `#search_section`, **or** resolve via `document.getElementById("search_section")` / outlet. Prefer a target on the frame: put `data-controller="search"` on `main` (or a wrapper that contains both dock and section) so the frame can be a target.

Recommended controller placement: `data-controller="search"` on `main.search--window`, with:

- `data-search-target="input"` on the field
- `data-search-target="section"` on the turbo-frame
- form/dock stay as today without their own controller attribute

### `search_controller.js`

```js
import { Controller } from "@hotwired/stimulus"
import { debounce } from "helpers/debounce"

const DEFAULT_DEBOUNCE_MS = 80

export default class extends Controller {
  static targets = ["input", "section"]
  static values = { path: String, debounceMs: { type: Number, default: DEFAULT_DEBOUNCE_MS } }

  connect() {
    this.#debouncedReplace = debounce(() => this.#replaceSection(), this.debounceMsValue)
  }

  input() {
    this.#debouncedReplace()
  }

  cleanup() {
    this.inputTarget.value = ""
    this.inputTarget.dispatchEvent(new Event("input", { bubbles: true }))
    this.inputTarget.focus()
    this.#replaceSection() // immediate restore of navigation; skip debounce
  }

  #replaceSection() {
    if (!this.hasSectionTarget) return
    const q = this.inputTarget.value.trim()
    const url = new URL(this.pathValue || "/search", window.location.origin)
    if (q) url.searchParams.set("q", q)
    else url.searchParams.delete("q")
    this.sectionTarget.src = url.pathname + url.search
  }
}
```

Wire `data-action="input->search#input"` on the field. `data-search-path-value="<%= search_path %>"` on the controller element.

`cleanup` clears the value, focuses, and immediately sets section `src` to `/search` (same as empty query). The `input` event may also schedule a debounced replace — either cancel debounce in cleanup or make `#replaceSection` idempotent (setting the same src twice is OK).

## Controller (`SearchesController#show`)

Existing logic mostly stands:

- Always prepare navigation data (`@collections`, counts) on full HTML.
- When `@q.present?`: `@entries = Search::GlobalRequest.call(..., limit: 10)` (page/frame card cap).
- When blank and (html or frame): no `@entries`; render navigation.
- Frame request with `q`: results only inside the frame.
- Frame request without `q`: navigation only inside the frame.

Avoid loading `@collections` on frame+query requests if unused (optional optimization).

## CSS

Rename `.search--clear-button` → `.search--cleanup` everywhere (including `:has(...): .search--cleanup` collapse rules). Add light `.search--results` / empty-state spacing if needed; no new card chrome required.

## Testing

- Hub/navigation still on `GET /search` inside `#search_section`.
- `GET /search?q=milk` as turbo-frame `search_section` returns results markup (matching bullet), not navigation.
- `GET /search` as turbo-frame `search_section` returns navigation.
- Assert `.search--cleanup` present; no `.search--clear-button`.
- Keep asserting legacy `#index-query` / `#index_results` absent.

## Out of scope

- Recent selections / open crossfade / Escape-to-close
- Hit highlighting beyond existing bullet rendering
- Keyboard combobox navigation of results
- Recording `Search::Selection` on click
