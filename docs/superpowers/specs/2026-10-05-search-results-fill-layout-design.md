# Search results fill layout — design

**Date:** 2026-10-05  
**Status:** Approved

## Goal

Keep the empty Search hub vertically centered. When a query is present, replace the whole hub (including the `Search` title) with classical top-aligned results that fill the scroller. The frame wrapper must not branch on content type.

Builds on [`2026-10-05-search-section-frame-design.md`](2026-10-05-search-section-frame-design.md). Supersedes that doc’s decision that `h1` stays outside the frame.

## Decisions

| Decision | Choice |
| --- | --- |
| Frame contents | Entire scroller body (title + navigation **or** results) |
| Empty query | Hub: `h1` + `_navigation` inside `#search_section` |
| Query present | Only `_results` inside `#search_section` (no title, no nav) |
| Empty results | Same results mode (`No results`), still no title |
| Centering | Owned by hub content, not the wrapper |
| Wrapper CSS | Content-agnostic: fill scroller height only |
| Stimulus | Unchanged (`sectionTarget.src`) |

## Page structure

```erb
<div class="timeline--scroller search--scroller">
  <%= turbo_frame_tag "search_section",
        class: "search--section",
        data: { search_target: "section" } do %>
    <% if @q.present? %>
      <%= render "results", entries: @entries %>
    <% else %>
      <div class="search--hub">
        <h1>Search</h1>
        <%= render "navigation" %>
      </div>
    <% end %>
  <% end %>
</div>
```

Dock stays outside the frame.

## Layout CSS

```css
.search--window .search--scroller {
  /* existing padding; first child no longer special-cases the old external h1 */
}

.search--section {
  display: flex;
  flex-direction: column;
  flex: 1;
  min-block-size: 0;
  /* no margin-block: auto, no :has() modes */
}

.search--hub {
  display: flex;
  flex: 1;
  flex-direction: column;
  justify-content: center;
  gap: var(--space-v-4);
  min-block-size: 0;
}

.search--results {
  display: flex;
  flex-direction: column;
  gap: var(--space-v);
  /* top of the section; does not grow to center itself */
}
```

Remove today’s rule that centers `.search--section` via `margin-block: auto`.

## Behavior

1. `GET /search` — hub centered in leftover space under the dock.
2. Typing / `GET /search?q=…` (full page or `Turbo-Frame: search_section`) — frame swaps to results; list starts at the top; title gone.
3. Cleanup / empty `q` — frame restores hub with title + centering.

## Testing

- Hub: `turbo-frame#search_section` contains `h1` “Search” and `#search_navigation`; no `.search--results`.
- Query (full + frame): frame contains `.search--results`, no `h1`, no `#search_navigation`.
- Empty query frame: hub again (title + navigation).

## Out of scope

- Result count / query-as-title
- Changing result row markup or search backend
- Stimulus debounce / cleanup behavior
