# Design: Visual Indentation & Title Bulletable Type

## 1. Goal

Allow bullets to be visually indented in the timeline, and introduce a new `Title` bulletable type that renders as a large heading. This creates lightweight visual trees without parent-child relationships.

## 2. Data Model

### 2.1 Indentation

- Add `indented` boolean to `bullets` table: `default: false, null: false`.
- Exposed as `f.check_box :indented` in the composer. Available for all bulletable types.
- Purely visual; no DB-level parent/child links.

### 2.2 Title bulletable type

- New table `titles`: `text` (string, not null), `created_at`, `updated_at`.
- New model `Title` including `Bulletable`.
- `Title` overrides:
  - `marker_icon` → `:none` or hidden
  - `marker_styles` → none
  - `name` / `excerpt` → `text`
  - `temporal?` → `false`
  - `completable?` → `false`
- Update `Bullet.delegated_type` types array to `%w[Task Note Event Title]`.
- Update `Bullet` validation: skip `body_or_rich_body_present` when `bulletable_type == "Title"` (Title has no Action Text body).

## 3. Rendering

### 3.1 Indented bullets

- `_bullet.html.erb`: add `data-bullet-indented="<%= bullet.indented %>"`.
- `bullet.css`: `[data-bullet-indented="true"] { margin-inline-start: 2rem; }` (or nearest spacing variable).
- Checkbox and marker remain in place; only `.bullet--body` shifts.

### 3.2 Title bullets

- `_bullet.html.erb`: conditional for `Title`:
  - Render marker slot empty (maintain grid alignment).
  - Render checkbox for bulk actions (Titles participate in bulk).
  - Render `bullet.name` as a large bold heading (no link, no attachments, no metadata).
  - Skip attachments, metadata, and rich body blocks entirely.
- `_compact.html.erb` (monthly bucket): render as bold truncated text, no marker.

## 4. Composer

### 4.1 Indentation toggle

- Add "Indent" checkbox in `_form_fields.html.erb`, near the type selector row or actions row.
- Persisted via `f.check_box :indented`.

### 4.2 Title type

- When `bulletable_type` selects "Title":
  - Hide the inline `body` rich-text editor.
  - Show a plain text `input` for `bulletable.text` (via `fields_for :bulletable`).
  - Hide the Expand button and note-options block.
  - Hide or neutralize the marker preview.
- On edit, pre-fill the text input.
- The composer Stimulus controller (`bullet-composer`) handles type-change visibility toggling.

## 5. Validation & Edge Cases

- `Title` validates `text` presence.
- `Bullet` with `Title` is valid without `body` / `rich_body`.
- Titles participate in all bulk actions (pin, archive, collect, pop).
- Indented bullets participate in bulk actions normally.
- No restrictions on what follows what (an indented Title is allowed, even if visually odd).

## 6. Testing

- Model: `Title` presence validation; `Bullet` with `Title` valid without body; `indented` assignment.
- Controller: create/update Title bullet; set `indented` flag.
- System (if applicable): composer shows plain text input for Title; indented bullets have visual offset.

## 7. Migration Summary

1. `add_column :bullets, :indented, :boolean, default: false, null: false`
2. `create_table :titles` with `text:string` and timestamps
3. Update `Bullet` delegated_type list
4. No data migration required
