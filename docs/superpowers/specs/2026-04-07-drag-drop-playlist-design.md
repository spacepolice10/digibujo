# Drag-and-Drop Cards into Playlists

**Date:** 2026-04-07
**Status:** Approved

## Overview

Allow users to drag cards from the Timeline and drop them onto playlist lanes in the dock to add them to a playlist. Desktop only — no touch/mobile support.

## Behaviour

- Every card in the Timeline is draggable by clicking and holding anywhere on the card body.
- The dock renders one drop zone per playlist lane. Dragging a card over a lane highlights that lane; releasing the mouse adds the card to that playlist.
- If a card is already in the target playlist, the server rejects the duplicate (uniqueness validation already exists on `PlaylistCard`) and the UI silently ignores the failure — the dock does not update.
- On success, the dock lane updates in place via the existing Turbo Stream response (`playlists/cards/create.turbo_stream.erb` already replaces the lane).

## Architecture

Two new Stimulus controllers that communicate exclusively via the browser's native `dataTransfer` API — no shared Stimulus state, no cross-frame coupling.

### `card_drag_controller`

Mounted on each `.card` div.

**Responsibilities:**
- On `dragstart`: write the card ID into `dataTransfer` and add the `.dragging` CSS class to the card element.
- On `dragend`: remove the `.dragging` class.

**Values:**
- `id` (String) — the card's database ID, set from ERB.

### `playlist_drop_controller`

Mounted on each playlist lane (`<section class="pinned-dock__lane">`) in `playlists/_dock_stack.html.erb`.

**Responsibilities:**
- On `dragover`: call `event.preventDefault()` (required by the browser to permit a drop) and add `.drag-over` to the lane element.
- On `dragleave`: remove `.drag-over`.
- On `drop`: prevent default, read the card ID from `dataTransfer`, POST to the playlist cards endpoint, render the Turbo Stream response, remove `.drag-over`.

**Values:**
- `url` (String) — `playlist_cards_path(playlist)`, set from ERB.

**Data flow on drop:**
```
fetch(urlValue, {
  method: "POST",
  headers: {
    "Content-Type": "application/json",
    "X-CSRF-Token": <csrf token>,
    "Accept": "text/vnd.turbo-stream.html"
  },
  body: JSON.stringify({ card_id: cardId })
})
→ if response.ok: Turbo.renderStreamMessage(await response.text())
→ non-2xx: silently ignored
```

## Markup Changes

### `app/views/cards/_card.html.erb`

- Add `draggable="true"` to the outer `.card` div.
- Add `data-controller="card-drag"` and `data-card-drag-id-value="<%= card.id %>"` to the outer `.card` div.
- Add `data-action="dragstart->card-drag#dragstart dragend->card-drag#dragend"` to the outer `.card` div.
- Add `draggable="false"` to the `.card-body` anchor to prevent the browser from trying to drag the link instead of the card container.

### `app/views/playlists/_dock_stack.html.erb`

- Add `data-controller="playlist-drop"` to the `<section>` lane element.
- Add `data-playlist-drop-url-value="<%= playlist_cards_path(playlist) %>"` to the `<section>` lane element.
- Add `data-action="dragover->playlist-drop#dragover dragleave->playlist-drop#dragleave drop->playlist-drop#drop"` to the `<section>` lane element.
- Add `--lane-colour: <%= playlist.colour_variable %>` to the `<section>` element's inline `style` attribute so the drag-over glow can reference the playlist's colour.

## CSS States

Added to the relevant stylesheet (cards and dock):

```css
/* Card drag source */
.card                { cursor: grab; }
.card.dragging       { opacity: 0.35; cursor: grabbing; }

/* Dock lane drop target */
.pinned-dock__lane.drag-over {
  outline: 2px solid var(--lane-colour);
  box-shadow: 0 0 14px var(--lane-colour);
  border-radius: var(--radius);
}
```

`--lane-colour` is set as an inline CSS custom property on the `<section>` element in `_dock_stack.html.erb` (e.g. `style="--lane-colour: <%= playlist.colour_variable %>"`) — this is a per-instance inline variable, not a new global variable.

## Out of Scope

- Touch/mobile drag and drop.
- Visual feedback for duplicate-card drops (handled silently).
- Drag-to-reorder within the playlist popover (separate feature, separate controller).
- Drag from anywhere other than the Timeline card list.
