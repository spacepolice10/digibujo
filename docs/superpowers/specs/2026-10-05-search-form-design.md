# Search form (composer-style dock) — design

**Date:** 2026-10-05  
**Status:** Approved

## Goal

Add a Search field docked at the bottom of the Search page that **looks and animates like the timeline composer**: text field plus a trailing close control that reveals once the field has at least one character. Close clears the field. Live query submission and results UI are deferred.

This is a visual-first slice toward the dock described in [`2026-10-01-unified-search-page-design.md`](2026-10-01-unified-search-page-design.md). It does **not** implement open/close hub crossfade or debounced live fetch yet.

## Decisions

| Decision | Choice |
| --- | --- |
| Approach | Parallel `search.css` + CSS `:has()`, not reuse of `.composer` classes |
| Input class | `.search--textform` |
| Close behavior | Clear the input and refocus (hub reset later when open-state exists) |
| Submit / live search | Out of scope this pass |
| Placement | Bottom of `searches/show`, docked like composer (tabbar clearance) |
| Left control | None for now |
| Close icon | `x` (same as dialogs / bulk menu) |

## Markup (`app/views/searches/_form.html.erb`)

Shell:

```erb
<div class="search" data-controller="search">
  <form …> <!-- GET search_path; submit unused for now -->
    <input
      type="search"
      name="q"
      class="search--textform"
      placeholder="Search…"
      value="<%= @q %>"
      data-search-target="input"
      autocomplete="off"
    >
    <button
      type="button"
      class="search--control search--clear-button"
      aria-label="Clear search"
      data-action="search#clear"
    >
      <%= icon("x") %>
    </button>
  </form>
</div>
```

Notes:

- Real placeholder required so `:placeholder-shown` drives the clear reveal.
- Hide native search cancel (`::-webkit-search-cancel-button`) so only our control shows.
- Prefer `type="search"` for semantics; visual styling matches a plain field, not browser chrome.

## Page (`app/views/searches/show.html.erb`)

Render the form at the **bottom** of the page inside a dock wrapper analogous to the timeline composer dock:

- Wrapper classes: e.g. `search--dock` (mirror `.composer--dock` spacing / `margin-block-end: var(--tabbar-clearance)`).
- Do not convert the Search hub into a `chat--window` in this pass unless layout requires it for docking; keep hub content scrolling normally above the dock.

## CSS (`app/assets/stylesheets/search.css`)

Add alongside existing `.search--navigation-item-counter`:

| Class | Role |
| --- | --- |
| `.search--dock` | Bottom dock spacing / tabbar clearance (composer twin) |
| `.search` | Flex row, same min-height / gap as `.composer` |
| `.search--textform` | Growing field; light focus treatment aligned with Lexxy focus (border / optional bounce) |
| `.search--control` | Same size, radius, shadow, transition recipe as `.composer--control` |
| `.search--clear-button` | Trailing control; default collapsed |

Reveal pattern (mirror composer submit):

- Default (empty / `:placeholder-shown`): clear button `width: 0`, `opacity: 0`, `scale: 0.5`, `visibility: hidden`, `pointer-events: none`, negative margin to collapse the gap.
- When `.search:has(.search--textform:not(:placeholder-shown))`: clear button expands to full control size with the same cubic-bezier enter as composer.
- `prefers-reduced-motion: reduce` → no transitions.

Do not couple to `.composer` selectors; duplicate the motion tokens so search can evolve independently.

## Stimulus (`app/javascript/controllers/search_controller.js`)

Minimal controller:

- Target: `input`
- Action `clear`: set `input.value = ""`, dispatch `input` (so CSS `:placeholder-shown` updates), `focus()` the input.

No debounce, no turbo-frame `src`, no Escape handling in this pass (those belong with the unified open/close work).

Register via existing Stimulus index / eager load convention.

## Testing

- `SearchesControllerTest#show renders the hub`: assert the new search field / clear button are present (e.g. `input.search--textform`, clear `button[aria-label="Clear search"]`).
- Keep asserting legacy `input#index-query` and `turbo-frame#index_results` remain absent until live results return.
- Optional system smoke: typing one character reveals clear; clicking clear empties the field (only if cheap to add with existing system helpers).

## Out of scope

- Debounced live `GET /search?q=…` / turbo-frame results
- Hub ↔ recent panel crossfade / `search--open`
- Escape-to-close
- Left-side icon / attach-style control
- ⌘K / hotkey focus wiring changes
- Converting Search into a full `chat--window` layout

## Follow-ups

Wire submission and open-state behavior per the unified Search page design once this dock shell lands.
