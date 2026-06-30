# Lexxy

[Lexxy](https://github.com/basecamp/lexxy) is Basecamp's modern Action Text editor, built on [Lexical](https://lexical.dev). Replaces Trix. This app uses `lexxy ~> 0.9.18`.

- **Upstream docs**: https://basecamp.github.io/lexxy
- **Prompts**: https://basecamp.github.io/lexxy/prompts.html
- **Source**: https://github.com/basecamp/lexxy
- **Reference projects** (all use Lexxy as their Action Text editor):
  - [Fizzy](https://github.com/basecamp/fizzy) — `@`/`#` prompts and rich composes.
  - [Writebook](https://github.com/basecamp/writebook) — inline + expand composes for long-form content.
  - [Campfire](https://github.com/basecamp/campfire) — message composes with attachments.
  - [Lexxy](https://github.com/basecamp/lexxy) — `lexical-editor-element.ts` and `lexical-extension.ts` for internals.

## Core concepts

| Concept | What it is |
|---|---|
| `<lexxy-editor>` | Form-associated web component; `value` syncs to a hidden form field on change |
| Preset | Named config block passed via `preset="..."` and `Lexxy.configure({ name: {...} })` |
| `<lexxy-prompt>` | Trigger-based popover (`#`, `@`, `/`) for suggestions or commands |
| `<lexxy-prompt-item>` | Suggestion row with `<template type="menu">` and `<template type="editor">` |
| Custom attachment | Prompt selection inserts an Action Text attachment (via `sgid` + `content-type` on the editor template) |
| File attachment | Active Storage blob inserted inline, or intercepted for direct upload (see below) |
| Custom events | `lexxy:change`, `lexxy:file-accept`, `lexxy:editor-initialized`, `lexxy:upload-*` |
| Extension | A `LexxyExtension` subclass; `lexicalExtension.register(editor)` returns a cleanup function |
| Sanitization | Lexxy widens Action Text's allowed tags/attrs; Loofah is configured to allow `var()` in CSS |

## How this app uses it

### Presets

Configured in `app/javascript/application.js`:

| Preset | Used for | Toolbar | Multi-line | Markdown |
|---|---|---|---|---|
| `inline` | Task, Event body | off | no | no |
| `note` | Note body | on | yes | yes |

Both presets register `InlinePastingExtension` and `PromptActionExtension` via `global.extensions`.

The editor markup lives in `app/views/bullets/composer/_editor.html.erb` — `preset: "inline"` or `preset: "note"` depending on bullet type.

### Prompts

Follows Lexxy's [custom attachments with remote loading](https://basecamp.github.io/lexxy/prompts.html) pattern.

| Trigger | Name | Source | Inserts |
|---|---|---|---|
| `#` | `project` | `GET /projects/suggestions?filter=…` | Project pill (`application/vnd.actiontext.project`) |
| `@` | `person` | `GET /people/suggestions?filter=…` | Person pill (`application/vnd.actiontext.person`) |
| `/` | `action` | inline items in the editor partial | Stimulus commands (type switch, file picker) — no editor insertion |

Remote prompts use `remote-filtering` and `supports-space-in-searches`. Lexxy sends **`filter`**, not `q`.

Suggestion responses render `lexxy-prompt-item` rows from:

- `app/views/projects/_prompt_item.html.erb`
- `app/views/people/_prompt_item.html.erb`

Each item provides:

- `search` — text matched when filtering
- `sgid` — attachable signed global id for Action Text
- `template[type="menu"]` — dropdown row
- `template[type="editor"]` — HTML embedded in the attachment node when selected

### Custom extensions

`app/javascript/extensions/`:

- **`inline_pasting.js`** — strips rich paste in inline editors (plain text only).
- **`prompt_actions.js`** — `/` prompt items can run Stimulus actions instead of inserting into the editor. Put `data-action` on a button inside `template[type="menu"]`; the extension finds the active prompt and invokes the action.

### Direct uploads

Note preset enables attachments via Lexxy (`attachments: true` in `app/javascript/application.js`).

### Attachment hydration

Stored Action Text HTML keeps attachment nodes as lightweight references. On load, Lexxy's `rich_text_area` hydrates them via the gem's `render_custom_attachments_in` (uses each attachable's `to_attachable_partial_path`). New `#` / `@` picks embed editor pill HTML from prompt `template[type="editor"]`:

- `app/views/projects/_attachable_editor.html.erb`
- `app/views/people/_attachable_editor.html.erb`

Read views use separate attachable partials (`projects/_attachable`, `people/_attachable`).

### Turbo morph

The `<lexxy-editor>` web component handles disconnect/reconnect to survive Turbo Drive morphs without losing value or focus.

## Patching guide

| Goal | Where |
|---|---|
| Editor behavior / presets | `app/javascript/application.js` (`Lexxy.configure`) |
| Custom Lexxy extensions | `app/javascript/extensions/*.js` |
| Prompt triggers and layout | `app/views/bullets/composer/_editor.html.erb` |
| Prompt suggestion rows | `app/views/projects/_prompt_item.html.erb`, `app/views/people/_prompt_item.html.erb` |
| Pill HTML in the editor | `app/views/*/_attachable_editor.html.erb` |
| Composer submit / reset | `app/javascript/controllers/composer_controller.js` |
| Styling | Gem `lexxy.css`, `app/assets/stylesheets/actiontext.css` |
| Upstream fix | Issue / PR on https://github.com/basecamp/lexxy |

## Debugging

- `document.querySelector('lexxy-editor').value` — current editor HTML.
- `document.querySelector('lexxy-editor').closest('form').querySelector('[name$="[body]"]')?.value` — value that will submit with the form.
- `LexicalEditorElement.debug = true` in the console — verbose logging.
- Watch `lexxy:editor-initialized` and `lexxy:change` on the editor element.

## When NOT to use Lexxy

- Collaborative real-time editing — Lexxy is single-user; look at Lexical's Yjs bindings instead.
- No-JS editor — use a plain `text_area` and Action Text without an editor.
- iframe-isolated editors — Lexxy assumes same-document, form-associated context.
- Non-HTML embed contexts (PDF, RSS) — strip Action Text body to plain text first.
