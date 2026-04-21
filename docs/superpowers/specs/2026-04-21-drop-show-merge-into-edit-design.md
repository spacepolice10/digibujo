# Drop `cards#show` — Merge Into Edit

**Date:** 2026-04-21

## Summary

Remove the `cards#show` route and view entirely. The inline edit toggle (click-to-edit, read/edit view swap) was the only reason show existed as a separate page. Replacing it with the always-visible form on `cards#edit` eliminates complexity with no loss of functionality.

---

## Changes

### `app/views/cards/edit.html.erb`

Replace the current minimal edit page (Back link + form) with an expanded layout:

- **Nav**: Back button — replace the current `link_to card_path(@card)` with `<button class="button-tertiary" onclick="history.back()">` (same pattern as show), plus Delete, Pin, and Publish action buttons moved from the show nav.
- **Body**: The `render "form"` stays as-is.
- **Footer**: `<% if @card.popped? %> <%= render "cards/triage", card: @card %> <% end %>` moved from show.

The card meta header (type badge, mood emoji, pinned badge, tags display) from show is **not carried over** — those values are already editable through the form's type picker, mood picker, and tags fields.

### `app/controllers/cards_controller.rb`

- Remove `show` from the `before_action :set_card` list.
- Delete `def show`.
- Change `redirect_to @card` in `create` → `redirect_to edit_card_path(@card)`.
- Change `redirect_to @card` in `update` → `redirect_to edit_card_path(@card)`.

### `config/routes.rb`

Add `except: :show` to the cards resource declaration.

### Link updates

All GET links that currently point to `card_path` (show) are updated to `edit_card_path`:

| File | Line | Change |
|------|------|--------|
| `app/views/cards/_card.html.erb` | card title `href` | `card_path(card)` → `edit_card_path(card)` |
| `app/views/calendars/show.html.erb` | event title link | `card_path(card)` → `edit_card_path(card)` |
| `app/views/cards/_calendar_card.html.erb` | title link | `card_path(card)` → `edit_card_path(card)` |

Note: `button_to card_path(card), method: :delete` calls are unchanged — DELETE to `/cards/:id` still hits `destroy`.

### Deletions

- `app/views/cards/show.html.erb`
- `app/javascript/controllers/card_inline_edit_controller.js`

### `app/assets/stylesheets/card-show.css`

- Replace the `[data-card-inline-edit-target="editView"] [data-controller~="card-form"]` scoping rule with `.card-show-content [data-controller~="card-form"]` so the form still renders transparently inside the card-show-content area.
- Remove `.card-show-body` block (read-mode prose styles, no longer needed).
- Remove the image-zoom overlay styles (`.image-zoom-overlay`, `[data-controller="image-zoom"]`).

---

## Out of Scope

- The `image-zoom` Stimulus controller itself is not deleted — it may be used elsewhere.
- No changes to Turbo Stream responses or other card sub-resource controllers.
- No changes to the drafts triage flow (`/drafts`).
