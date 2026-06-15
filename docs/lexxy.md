# Lexxy — internal reference (Digibujo)

Reference for patching and extending Lexxy in this app. Lexxy is Basecamp’s Action Text editor built on [Lexical](https://lexical.dev).

- **Gem**: `lexxy ~> 0.9.18` (`Gemfile`)
- **Installed path**: `bundle show lexxy` → e.g. `…/gems/lexxy-0.9.18`
- **Public docs**: https://basecamp.github.io/lexxy
- **Source**: https://github.com/basecamp/lexxy

---

## Architecture overview

```
┌─────────────────────────────────────────────────────────────────┐
│  Rails (Ruby)                                                   │
│  Lexxy::Engine → overrides Action Text helpers                  │
│  lexxy_rich_textarea_tag → <lexxy-editor> web component         │
│  Hydrates attachment `content` JSON for editor load             │
└────────────────────────────┬────────────────────────────────────┘
                             │ value= HTML, data-direct-upload-url
┌────────────────────────────▼────────────────────────────────────┐
│  Browser (lexxy.js — bundled Lexical + web components)            │
│  <lexxy-editor> → Lexical editor in .lexxy-editor__content        │
│  Exports sanitized HTML matching Action Text canonical format   │
└────────────────────────────┬────────────────────────────────────┘
                             │ POST form field (hidden value sync)
┌────────────────────────────▼────────────────────────────────────┐
│  Action Text                                                    │
│  RichText body → attachables, Active Storage blobs, custom SGIDs│
└─────────────────────────────────────────────────────────────────┘
```

**Two integration paths in Rails 8.1:**

1. **Editor adapter** (`ActionText::Editor::LexxyEditor`) — when `ActionText::Editor#editor_tag` supports blocks (`Lexxy.supports_editor_adapter?`).
2. **Monkey-patch fallback** — prepends `Lexxy::TagHelper`, `FormHelper`, etc. and aliases `rich_text_area` → `lexxy_rich_textarea`. Digibujo uses this path plus its own `Digibujo::LexxyEditorAttachments` prepend on `Lexxy::TagHelper`.

---

## Ruby layer (gem)

| File | Role |
|------|------|
| `lib/lexxy.rb` | Module API, `override_action_text_defaults` |
| `lib/lexxy/engine.rb` | Railtie: editor adapter or monkey-patch, sanitization, assets, attachable hook |
| `lib/lexxy/rich_text_area_tag.rb` | `Lexxy::TagHelper#lexxy_rich_textarea_tag` — builds `<lexxy-editor>` |
| `lib/lexxy/form_helper.rb` / `form_builder.rb` | Form integration |
| `lib/lexxy/attachable.rb` | Adds `RemoteVideo` attachable resolution |
| `lib/action_text/editor/lexxy_editor.rb` | Rails 8.2+ editor adapter |
| `lib/active_storage/blob_with_preview_url.rb` | Adds `previewable` + preview `url` to blob JSON |
| `lib/action_text/attachables/remote_video.rb` | Video URL attachables |

### `lexxy_rich_textarea_tag` output

Renders `<lexxy-editor>` with:

- `name`, `value` (HTML string)
- `class="lexxy-content"` (default)
- `data-direct-upload-url` → `rails_direct_uploads_url`
- `data-blob-url-template` → `rails_service_blob_url(":signed_id", ":filename")`
- Optional block children: `<lexxy-prompt>`, custom toolbar, etc.

### Attachment hydration (load path)

Before the editor renders stored content, `render_custom_attachments_in` walks `action-text-attachment` nodes. When `url` is blank, it sets:

- `content` → JSON of rendered partial HTML (`render_action_text_attachment`)
- `content-type` from the attachment

**Digibujo override** (`config/initializers/lexxy.rb`): `Project` attachables use `projects/attachable_editor` instead of the default partial so pills render correctly in the editor.

### Sanitization extensions

Lexxy widens Action Text allowed tags/attributes for tables, video, etc., and allows CSS `var()` in Loofah.

---

## JavaScript layer (lexxy.js)

Single ESM bundle (~16.7k lines minified). Pinned via importmap:

```ruby
pin "lexxy", to: "lexxy.js"
```

### Public exports

```javascript
import * as Lexxy from "lexxy"

// Configuration
Lexxy.configure({ global: { extensions: [...] }, inline: {...}, note: {...} })

// Extension base class
import { Extension, $isActionTextAttachmentNode, $createActionTextAttachmentNode, ... } from "lexxy"

// Utilities
highlightCode(root), highlightElement(pre), NativeAdapter
```

### Global config (`Lexxy.global`)

| Key | Default | Purpose |
|-----|---------|---------|
| `attachmentTagName` | `"action-text-attachment"` | DOM tag for attachments |
| `attachmentContentTypeNamespace` | `"actiontext"` | MIME namespace for prompts: `application/vnd.{namespace}.{name}` |
| `authenticatedUploads` | `false` | Upload auth behavior |
| `extensions` | `[]` | Array of `LexxyExtension` subclasses |

### Presets (`Lexxy.presets`)

Merged by `preset` attribute on `<lexxy-editor>` (default preset name: `"default"`).

Default preset keys:

| Key | Default | HTML attribute override |
|-----|---------|-------------------------|
| `attachments` | `true` | `attachments` |
| `markdown` | `true` | `markdown` |
| `multiLine` | `true` | `multiline` |
| `richText` | `true` | `richtext` |
| `permittedAttachmentTypes` | `null` (all) | `permitted-attachment-types` |
| `toolbar` | `{ upload: "both" }` | nested via `toolbar` |
| `highlight` | color/bg button vars | nested |

**Digibujo presets** (`app/javascript/application.js`):

```javascript
Lexxy.configure({
  global: { extensions: [InlinePasteExtension] },
  inline: { attachments: true, toolbar: false, multiLine: false, richText: true, markdown: false },
  expand: { attachments: true, toolbar: true, multiLine: true, richText: true, markdown: true },
})
```

The `inline` preset is used for task/event composers (single-line feel, no toolbar). `InlinePasteExtension` strips HTML formatting on paste into inline editors and inserts plain text with URL and code detection.

---

## Web components

Registered in `defineElements()` (order matters):

| Element | Class | Notes |
|---------|-------|-------|
| `lexxy-toolbar` | `LexicalToolbarElement` | Must register **before** editor |
| `lexxy-toolbar-dropdown` | `ToolbarDropdown` | |
| `lexxy-highlight-dropdown` | `HighlightDropdown` | |
| `lexxy-link-dropdown` | `LinkDropdown` | |
| `lexxy-editor` | `LexicalEditorElement` | Form-associated custom element |
| `lexxy-prompt` | `LexicalPromptElement` | Must register **after** editor |
| `lexxy-code-language-picker` | `CodeLanguagePicker` | |
| `lexxy-node-delete-button` | `NodeDeleteButton` | On attachments |
| `lexxy-table-tools` | `TableTools` | |

### `<lexxy-editor>` highlights

- **Form-associated**: `attachInternals()`, syncs hidden form value on change
- **Content root**: `.lexxy-editor__content` (`contenteditable`)
- **Turbo morph**: `disconnectedCallback` caches `valueBeforeDisconnect`; `connected` attribute triggers reconnect
- **Focus optimization**: skips redundant `editor.focus()` when already focused
- **Empty detection**: `isEmpty` / `isBlank` for placeholder styling

Important attributes:

| Attribute | Purpose |
|-----------|---------|
| `preset` | Config preset name (`inline`, `note`, `default`) |
| `placeholder` | Placeholder text |
| `autofocus` | Focus on connect |
| `required` | Form validation |
| `multiline` | Override preset `multiLine` |
| `single-line` | Legacy single-line mode |
| `connected` | Internal reconnect signal |

### `<lexxy-prompt>` highlights

| Attribute | Purpose |
|-----------|---------|
| `trigger` | Trigger string (e.g. `#`, `@`) |
| `name` | Prompt name → content-type suffix |
| `src` | URL for suggestions HTML |
| `remote-filtering` | Use `RemoteFilterSource` (debounced `filter` query param) |
| `supports-space-in-searches` | Space selects item vs continues filter |
| `only-at` | Regex for valid trigger position (default: start or after space/newline) |
| `vertical-direction` | `top` / `bottom` popover bias |

**Prompt sources:**

| Source | When | Filtering |
|--------|------|-----------|
| `InlinePromptSource` | No `src` | Local on `search` attribute |
| `DeferredPromptSource` | `src` without `remote-filtering` | Fetch once, filter locally |
| `RemoteFilterSource` | `src` + `remote-filtering` | `GET {src}?filter={query}` |

Response must be HTML containing `<lexxy-prompt-item>` elements.

### `<lexxy-prompt-item>` structure

```html
<lexxy-prompt-item search="searchable text" sgid="...">
  <template type="menu">…popover list row HTML…</template>
  <template type="editor" content-type="application/vnd.actiontext.project">
    …inline attachment HTML for editor…
  </template>
</lexxy-prompt-item>
```

On select: trigger text replaced by `CustomActionTextAttachmentNode` built from editor template.

---

## Lexical node types

| Node | Type string | Role |
|------|-------------|------|
| `ActionTextAttachmentNode` | `action_text_attachment` | Files, images, Active Storage blobs |
| `CustomActionTextAttachmentNode` | `custom_action_text_attachment` | Prompt attachables (`content` HTML + SGID) |
| `ActionTextAttachmentUploadNode` | (upload pipeline) | In-progress uploads |
| `ImageGalleryNode` | | Multiple preview images |
| `ProvisionalParagraphNode` | | Hidden paragraph for cursor between block nodes |
| `HorizontalDividerNode` | | HR / divider |

**Inline vs block attachments:** `ActionTextAttachmentNode.isInline()` — inline when parent is not image gallery.

**Custom attachable export:**

```html
<action-text-attachment
  sgid="..."
  content-type="application/vnd.actiontext.project"
  content="<span class='pill'>…</span>">
</action-text-attachment>
```

`content` is raw HTML (older Lexxy JSON-encoded it; `parseAttachmentContent` handles both).

---

## Built-in extensions (gem)

Registered via `LexicalEditorElement.baseExtensions`:

| Extension | Purpose |
|-----------|---------|
| `ProvisionalParagraphExtension` | Provisional paragraphs between blocks |
| `HighlightExtension` | Text color / background |
| `TrixContentExtension` | Trix HTML import compatibility |
| `TablesExtension` | Tables |
| `RewritableHistoryExtension` | Undo/redo |
| `AttachmentsExtension` | Upload, drag-drop, paste files |
| `FormatEscapeExtension` | Escape formatting at boundaries |
| `LinkOpenerExtension` | Link handling |
| `PreventLexicalTripleClickExtension` | Blocks Lexical triple-click selection |

App extensions are appended from `Lexxy.global.get("extensions")`.

### `LexxyExtension` API

```javascript
class MyExtension extends LexxyExtension {
  get enabled() { return true }           // optional filter
  get lexicalExtension() { return { name, register: (editor) => cleanup } }
  get allowedElements() { return [] }     // extra toolbar elements
  initializeToolbar(toolbar) { }          // add toolbar buttons
  dispose() { }                           // cleanup
}
```

`lexicalExtension.register(editor)` returns a cleanup function (Lexical plugin pattern).

---

## Custom events (`lexxy:*`)

Dispatched on `<lexxy-editor>` (unless noted):

| Event | Detail | Cancelable |
|-------|--------|------------|
| `lexxy:initialize` | — | No |
| `lexxy:editor-initialized` | adapter detail | No |
| `lexxy:change` | — | No |
| `lexxy:focus` / `lexxy:blur` | — | No |
| `lexxy:file-accept` | `{ file }` | **Yes** — reject disallowed types |
| `lexxy:upload-start` | `{ file }` | No |
| `lexxy:upload-progress` | `{ file, progress }` | No |
| `lexxy:upload-end` | `{ file, error }` | No |
| `lexxy:insert-link` | link detail | Yes |
| `lexxy:insert-markdown` | markdown detail | Yes |
| `lexxy:attributes-change` | `{ attributes, link, highlight, headingTag }` | No |
| `lexxy:code-language-picker-open` | `{ languages, currentLanguage }` | Yes |
| `lexxy:internal:move-to-next-line` | — | Internal |

---

## Digibujo integration map

### Files

| Path | Role |
|------|------|
| `config/initializers/lexxy.rb` | Project attachable hydration partial |
| `config/initializers/bullet_project_tags.rb` | Sync `project_ids` / `person_ids` from body on save |
| `app/javascript/application.js` | `Lexxy.configure` presets + extension |
| `app/javascript/extensions/inline_paste_extension.js` | Strip rich-HTML paste in inline editors |
| `app/assets/stylesheets/lexxy-variables.css` | Editor chrome overrides (loaded via `stylesheet_link_tag "lexxy"`) |
| `app/assets/stylesheets/attachment.css` | Attachment preview styling |
| `app/views/layouts/action_text/contents/_content.html.erb` | `.lexxy-content.rich-text-content` wrapper |
| `app/views/bullets/editors/_*.html.erb` | Composers with `#` / `@` prompts |
| `app/views/projects/_prompt_item.html.erb` | Project suggestion item |
| `app/views/people/_prompt_item.html.erb` | Person suggestion item |
| `app/models/concerns/projectable.rb` | `editor_content`, tag sync from body |
| `app/models/concerns/personable.rb` | Person tag sync |
| `app/models/project.rb` / `person.rb` | `ActionText::Attachable`, `content_type` |

### Content types

| Model | `content_type` | Editor partial | Display partial |
|-------|----------------|----------------|-----------------|
| Project | `application/vnd.actiontext.project` | `projects/attachable_editor` | `projects/attachable` |
| Person | `application/vnd.actiontext.person` | `people/attachable_editor` | `people/attachable` |

### `editor_content` flow

`Bullet#editor_content(default_projects:, default_people:)`:

1. Reads `body_before_type_cast` HTML
2. Appends missing project/person attachables as `ActionText::Attachment` HTML
3. Returns `ActionText::Content` (non-canonicalized) for `value:` on the editor

On save, `apply_project_tags_from_content!` / `apply_people_tags_from_content!` read attachables from the body and sync join tables.

### Suggestions API

`GET /projects/suggestions?filter=…` → collection of `_prompt_item` partials.

Lexxy `RemoteFilterSource` sends **`filter`** query param (not `q`). Digibujo controller also accepts `q` for other callers.

### `InlinePasteExtension`

Custom extension for the `inline` editor preset (task/event body). Intercepts paste in the capture phase when the clipboard carries both `text/html` and `text/plain` (rich paste). Prevents default rich-HTML insertion and instead:

1. **Single URL** → inserts as a link via `contents.createLink()`
2. **Code-like text** (multi-line with indentation or code patterns) → wraps in `<pre><code>` and inserts via `contents.insertHtml()`
3. **Plain text** → splits by newlines, wraps each line in `<p>`, and inserts via `contents.insertHtml()`

Pure `text/plain` pastes are left to Lexxy's built-in handler (which already does autolink detection). File uploads are left to the attachments handler.

---

## CSS

**Gem stylesheets** (via `stylesheet_link_tag "lexxy"`):

- `lexxy.css` — aggregator
- `lexxy-variables.css` — design tokens (`--highlight-*`, editor spacing)
- `lexxy-editor.css` — toolbar, content, prompts
- `lexxy-content.css` — rendered content (read mode)

**App overrides**: `app/assets/stylesheets/lexxy-variables.css` — composer sizing, inline attachment chrome, delete button as icon mask.

**Convention**: Rendered bullets use `.rich-text-content` alongside `.lexxy-content` for shared attachment rules in `attachment.css`.

---

## Patching guide

### Patch in the app (preferred)

| Goal | Approach |
|------|----------|
| Editor behavior | `Lexxy.configure` + custom `Extension` in `app/javascript/extensions/` |
| Attachment hydration | Prepend `Lexxy::TagHelper` (see `lexxy.rb`) |
| Prompt UI | ERB partials for `lexxy-prompt-item` templates |
| Styling | `lexxy-variables.css`, `attachment.css` |
| Allowed HTML | App initializer or `ActionText::ContentHelper` |
| Sync tags from body | Model concerns + `bullet_project_tags.rb` |

### Patch the gem

Options:

1. **Fork / PR** to https://github.com/basecamp/lexxy (upstream preferred for bugs/features).
2. **Bundler git/path** — point `gem 'lexxy'` to a fork temporarily.

Ruby gem files are small and readable; **JS is one bundled file** — source lives in the Lexxy repo (TypeScript), not in the gem.

### Debugging

- Set `LexicalEditorElement.debug = true` in console (static on class).
- Watch `lexxy:change` / `lexxy:editor-initialized` on the editor element.
- Inspect exported HTML: `document.querySelector('lexxy-editor').value`
- Compare stored body: `Bullet.find(id).content.body_before_type_cast`

### Turbo morph notes

Lexxy explicitly handles Turbo morph: disconnect preserves value, reconnect remounts Lexical root without stealing focus from unrelated fields. If morph issues appear, check `connected` attribute and `valueBeforeDisconnect`.

---

## Version / upgrade checklist

When bumping `lexxy` gem:

1. Run `bin/importmap` if pin changes.
2. Diff `lexxy.js` exports (`export { … }` at file end).
3. Re-test: inline composer, note composer (toolbar), `#` / `@` prompts, file paste/upload, project pill hydration, tag sync on save, Turbo morph on bullet edit.
4. Re-verify `InlinePasteExtension` — paste rich HTML into inline editor should strip formatting; paste code should create `<pre><code>`; paste URL should create link.
5. Check `Lexxy.supports_editor_adapter?` — Rails version may switch integration path.

---

## Quick reference — composer ERB

```erb
<%= f.rich_text_area :content,
      value: editor_value,
      preset: "inline",
      placeholder: "…",
      multiline: false do %>
  <lexxy-prompt trigger="#"
                name="project"
                src="<%= project_suggestions_path %>"
                remote-filtering
                supports-space-in-searches>
  </lexxy-prompt>
<% end %>
```

`rich_text_area` is aliased to Lexxy’s helper by the gem engine.
