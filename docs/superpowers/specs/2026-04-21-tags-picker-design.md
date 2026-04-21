# Tags Picker Design

**Date:** 2026-04-21
**Status:** Approved

## Overview

A dialog-based tag picker for the card form, matching the visual and behavioral pattern of the existing date picker. Users search for existing tags or create new ones, select multiple, preview their selection, and commit via a Save button that writes to a hidden form field.

---

## Data Layer

Tags are submitted via a single hidden field `name="card[tags_string]"`. The existing `Taggable` concern already parses this comma-separated format and handles tag creation/association on save.

**Format:** `"existing-tag, new-tag:colour-key, another-existing-tag"`

- Existing tags: just the name (colour already stored on the model)
- New tags: `name:colour_key` (colour key is `"1"`–`"8"` from `Colourable::COLOUR_KEYS`, assigned randomly client-side)

The hidden field is pre-populated from `card.tags_string` on render so editing a card with existing tags works correctly.

### Server change

Add a JSON response to the existing `TagsController#index`:

```
GET /tags.json?q=foo
→ { "tags": [{ "name": "foo", "colour": "3" }, ...] }
```

No new routes or controllers needed.

---

## Component Structure (`_tags_picker.html.erb`)

```
div.tags-picker [data-controller="tags-picker dialog"]
  button.button-secondary [commandfor="tags-picker-dialog" command="show-modal"]
    i.icon (tag icon)
    span [data-tags-picker-target="label"]  ← "Tags" or "2 tags" after save
  input[type=hidden name="card[tags_string]" data-tags-picker-target="hiddenField"]
  dialog#tags-picker-dialog.dialog [data-dialog-target="dialog"]
    input[type=search data-tags-picker-target="searchInput" data-action="input->tags-picker#search"]
    ul.tags-picker--suggestions [data-tags-picker-target="suggestions" role="listbox"]
    div.tags-picker--preview [data-tags-picker-target="preview"]
    div.tags-picker--footer
      button.button-primary [data-action="click->tags-picker#save"]  Save
```

The component reuses the existing `dialog` Stimulus controller for open/close behavior (same as `_date_picker.html.erb`).

---

## Stimulus Controller (`tags_picker_controller.js`)

### State

- `selectedTags` — `Map<name, colour|null>`. Colour is a string key (`"1"`–`"8"`), sourced from the JSON response for existing tags and assigned randomly for newly created ones. Null only when an existing tag has no colour stored.
- `this.abortController` — tracks the current in-flight fetch so it can be cancelled.

### On connect

Parse `hiddenField.value` (the existing `tags_string`) into `selectedTags` and render the preview. This ensures editing a card pre-populates correctly.

### `search(event)`

Called on every `input` event on the search field.

1. `this.abortController?.abort()` — cancel previous in-flight request
2. Create a new `AbortController`, store it on `this.abortController`
3. `fetch(/tags.json?q=..., { signal })` — pass the signal
4. On success: render suggestion list (see below)
5. On `AbortError`: no-op

If the search input is empty, clear the suggestions list without fetching.

### Suggestion list rendering

Each suggestion row shows:
- A pill styled with `--model-color-{colour}-bg`
- A checkmark if the tag is in `selectedTags`

If the query is non-empty and no returned tag has a name matching `query.toLowerCase()` exactly, append a "Create 'xyz'" row at the bottom. This check is done client-side — no additional field needed in the JSON response.

### Selecting an existing tag

Toggle the tag in `selectedTags` (add or remove), storing `{ name, colour }` from the fetched JSON data. Re-render suggestion checkmarks and preview pills.

### Selecting "Create 'xyz'"

1. Pick a random colour key from `["1", "2", "3", "4", "5", "6", "7", "8"]`
2. Add `{ name: query, colour }` to `selectedTags`
3. Clear the search input and suggestion list
4. Re-render preview pills

No server call — the tag is created server-side on form save via `Taggable#assign_tags`.

### `save()`

1. Build `tags_string` from `selectedTags`:
   - Colour present: `"name:colour"`
   - No colour: `"name"`
   - Join with `", "`
2. Write to `hiddenField.value`
3. Update button label: `"N tags"` if any selected, `"Tags"` if none
4. Close the dialog

---

## CSS (`tags-picker.css`)

Follow the file-scoped naming convention (block = `tags-picker`):

| Class | Purpose |
|---|---|
| `.tags-picker` | Root wrapper |
| `.tags-picker--suggestions` | Scrollable suggestion list |
| `.tags-picker--suggestion` | Individual suggestion row |
| `.tags-picker--suggestion.is-selected` | Checkmark visible |
| `.tags-picker--create` | "Create 'xyz'" row |
| `.tags-picker--preview` | Wrapping row of selected tag pills |
| `.tags-picker--footer` | Flex row, Save button aligned right |

Use existing CSS variables only — no new variables. Tag pills use `style="background: var(--model-color-{colour}-bg)"` inline (same as elsewhere in the app).

---

## Files Changed

| File | Change |
|---|---|
| `app/views/cards/fields/_tags_picker.html.erb` | Full rewrite |
| `app/javascript/controllers/tags_picker_controller.js` | Full implementation |
| `app/controllers/tags_controller.rb` | Add `format.json` to `index` |
| `app/assets/stylesheets/tags-picker.css` | Add component styles |

No migrations, no new routes, no new models.
