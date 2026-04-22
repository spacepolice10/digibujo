# Card Form Type Switcher Redesign

**Date:** 2026-04-22
**Status:** Approved

## Summary

Combine the hamburger switch button and the selected-type icon chip into a single back-arrow + type-icon pill. Restore widget trigger buttons (date, tags, mood) to full `button-secondary` styling.

---

## Context

The card form actions bar in `_form.html.erb` has two modes managed by `card-form` Stimulus controller:

- **types mode** — all type buttons shown with icon + label; user picks a type
- **fields mode** — only the selected type chip (icon only) is visible, plus a separate hamburger button that returns to types mode, plus the fields turbo-frame (date picker, tags picker, mood picker)

Two issues:
1. The hamburger button and selected-type chip are redundant separate elements. The type icon already communicates "what's selected" — the hamburger icon adds no information.
2. The widget trigger buttons (`button-secondary`) are stripped of their border and background by a CSS override in `card-form.css`, making them look naked and inconsistent with the rest of the UI.

---

## Design

### Combined type chip (fields mode)

Replace the two-element row `[☰] [● type icon]` with a single pill: `[← back arrow | ● type icon]`.

- The back arrow (left) communicates "tap to go back to type selector"
- A subtle divider separates arrow from icon
- The chip inherits the type's color (cobalt for Task, amber for Note, etc.) — same as current selected-type chip
- Clicking the chip in fields mode calls `showTypeSelector()` (returns to types mode)

The back-arrow icon (`--icon-arrow-left`) is added to each `card-form-type-button` label in the ERB. It is hidden in types mode via CSS and shown only on the selected chip in fields mode.

The `.card-form-switch` button is removed entirely from the markup.

**JS change:** `selectType` currently calls `showFields()` unconditionally when the radio is already checked. In fields mode this is a no-op, but with the combined chip we need it to call `showTypeSelector()` instead. Update the method to check `typeControlsTarget.dataset.mode`.

### Widget buttons as button-secondary

Remove the CSS block in `card-form.css` that overrides `button-secondary` styling on widget triggers inside `turbo-frame.card-form-fields`. The widgets already use `class="button-secondary"` in their partials — removing the override is sufficient.

Result: date, tags, and mood trigger buttons render with their standard border, background, and subtle color — consistent with other secondary actions throughout the UI.

---

## Files to Change

| File | Change |
|------|--------|
| `app/views/cards/_form.html.erb` | Remove `.card-form-switch` button; add `--back` icon to each type button label |
| `app/assets/stylesheets/card-form.css` | Remove `.card-form-switch` rules; add CSS to show/hide back-arrow icon; remove widget button-secondary override |
| `app/javascript/controllers/card_form_controller.js` | Update `selectType` to call `showTypeSelector` when already in fields mode |

---

## Behaviour Spec

### Fields mode
- Combined chip shows: `[← | ● type-icon]` in the type's accent color
- Clicking the chip calls `showTypeSelector()` → transitions to types mode
- Widget trigger buttons render as standard `button-secondary` (border, transparent bg, subtle color)

### Types mode (unchanged)
- All type buttons shown with icon + label text
- No hamburger button (removed)
- Selecting a type calls `selectType` → checks if radio is checked → calls `showFields()` and triggers `loadFields` via change event

### Back-arrow visibility
- Hidden by default (types mode and non-selected chips)
- Visible only on `.card-form-type-button:has(:checked)` when `[data-mode="fields"]`
- Uses CSS `display: none` / `display: inline-block` toggled by the mode selector

---

## Out of Scope

- Types mode visual changes (layout, animation)
- Keyboard shortcut behavior (`switchType`, `submit`)
- Field loading animation (`handleBeforeFrameRender`)
- Widget dialog internals (date picker, tags picker, mood picker)
