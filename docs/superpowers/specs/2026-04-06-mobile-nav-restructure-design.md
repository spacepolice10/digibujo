# Mobile Navigation Restructure — Design Spec

**Date:** 2026-04-06

## Context

The current mobile layout has 4 tabs (Streams, Cards, Upcoming, Calendar) and no access to the pinned cards or playlists that live in the desktop dock. This spec restructures the mobile tab bar into 4 semantically clearer sections and adds a dedicated Workspace page that surfaces pinned cards and playlists as grouped, scrollable card lists.

---

## Navigation Structure

4 tabs replacing the current 4:

| Tab | Route | Content |
|-----|-------|---------|
| **Index** | `/streams` | Type grid + saved filters (mirrors desktop left sidebar) |
| **Workspace** | `/pinned` | Pinned cards + playlists as vertical grouped sections |
| **Drafts** | `/cards` | Main card timeline |
| **Upcoming** | `/upcoming` | Upcoming tasks / calendar |

---

## Tab Bar

**File:** `app/views/layouts/mobile.html.erb`

Replace the existing 4 tabs (Streams → Cards → Upcoming → Calendar) with:

```
Index     Workspace     Drafts     Upcoming
--icon-list  --icon-pin  --icon-pencil  --icon-calendar
/streams     /pinned     /cards         /upcoming
```

Active state detection by controller name:
- Index: `streams`
- Workspace: `pinned`
- Drafts: `cards`
- Upcoming: `upcoming` (singular resource controller)

The FAB (`+ Card`) remains unchanged.

---

## Index Page

No view changes required. `StreamsController#index` already renders `app/views/streams/index.html.erb` which contains:
- Type grid tiles (All Cards, Tasks, Notes, Events, Daylogs, Archived)
- Filters section (named streams with icon + tag pills)
- Search and + stream action buttons in the header

On mobile this renders as a full page using the mobile layout. The turbo-frame wrapper (`id="streams_panel"`) becomes a regular container when visited directly.

---

## Workspace Page

**File:** `app/views/pinned/index.html.erb`

The `/pinned` route is used by both desktop (as a lazy-loaded turbo-frame inside `main-layout.html.erb`) and mobile (as a direct page visit). The view must render differently based on context, detected via `turbo_frame_request?`.

### Desktop (dock — unchanged)

When `turbo_frame_request?` is true, render the existing horizontal dock layout inside `<turbo-frame id="pinned_panel">`.

### Mobile (workspace page)

When `turbo_frame_request?` is false, render a vertical grouped list:

**Structure:**

```
[Pinned group]
  ▏ 📌  Pinned  · N cards
  [card]
  [card]
  ...

[Playlist group — repeated for each playlist]
  ▏ 🎨  Playlist  · N cards    ← color bar uses playlist colour variable
  [card]
  [card]
  ...

[Empty state — if no pinned cards and no playlists]
  "Nothing pinned or collected yet."
```

**Group header anatomy:**
- 3px vertical color bar (rounded), using `playlist.colour_variable` (`var(--model-color-N)`) for playlists, `var(--text)` for pinned
- Icon (16×16, `--icon-pin` for pinned; playlist's `icon` attribute for playlists)
- Label: "Pinned" for pinned group; "Playlist" for playlist groups (no names yet)
- Card count: right-aligned, subtle

**Card items:** use the existing `cards/card` partial with a `dom_prefix` of `"workspace"`. No layout changes to the card partial required.

**Ordering:** Pinned group always first. Playlists follow in `created_at: :desc` order (same as current dock).

### CSS additions

New classes in `main-layout.css` (or a new `workspace.css`):

```
.workspace              — page container, padding
.workspace__section     — per-group wrapper, margin-bottom
.workspace__group-header — flex row: bar + icon + label + count
.workspace__bar         — 3px × 20px, border-radius 2px, flex-shrink 0
.workspace__icon        — 16×16 icon
.workspace__label       — font-weight bold, font-size base
.workspace__count       — font-size small, color subtle, margin-left auto
```

---

## Drafts Page

No changes. `/cards` already renders the card timeline via the mobile layout.

---

## Upcoming Page

No changes. `/upcoming` already exists and renders via the mobile layout.

---

## Approach

**A — reuse existing routes.** The only significant new UI is the Workspace page layout. Everything else is already a full page; we're just updating which routes the tab bar links to.

---

## Files to Change

| File | Change |
|------|--------|
| `app/views/layouts/mobile.html.erb` | Replace tab bar links and icons |
| `app/views/pinned/index.html.erb` | Add `turbo_frame_request?` branch; new mobile workspace markup |
| `app/assets/stylesheets/main-layout.css` | Add `.workspace-*` CSS classes |

---

## Verification

1. **Tab bar** — all 4 tabs render, active state highlights the correct tab on each page
2. **Index tab** — `/streams` shows type grid + filter list on mobile
3. **Workspace tab** — `/pinned` shows vertical grouped list on mobile; desktop dock unchanged
4. **Pinned group** — only shows if user has pinned cards; correct count
5. **Playlist groups** — one per playlist, correct color bar and icon, correct card count
6. **Empty state** — Workspace renders a message when nothing is pinned or collected
7. **Desktop dock** — visiting `/pinned` as a turbo-frame (desktop) still renders the horizontal dock
8. **Drafts tab** — `/cards` timeline loads correctly
9. **Upcoming tab** — `/upcoming` loads correctly
10. **FAB** — `+ Card` button still visible and functional on all tabs
