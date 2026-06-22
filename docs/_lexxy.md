# Lexxy

[Lexxy](https://github.com/basecamp/lexxy) is Basecamp's modern Action Text editor, built on [Lexical](https://lexical.dev). Replaces Trix. This app uses `lexxy ~> 0.9.18`.

- **Upstream docs**: https://basecamp.github.io/lexxy
- **Source**: https://github.com/basecamp/lexxy
- **Reference projects** (all use Lexxy as their Action Text editor):
  - [Fizzy](https://github.com/basecamp/fizzy) — best examples of `@`/`#`-style prompts and rich composes.
  - [Writebook](https://github.com/basecamp/writebook) — best examples of inline + expand composes for long-form content.
  - [Campfire](https://github.com/basecamp/campfire) — best examples of message composes with attachments.
  - [Lexxy](https://github.com/basecamp/lexxy) — read the source for `lexical-editor-element.ts` and `lexical-extension.ts` to understand the internals.

## Core concepts

| Concept | What it is |
|---|---|
| `<lexxy-editor>` | Form-associated web component; `value` syncs to a hidden form field on change |
| Preset | Named config block passed via `preset="..."` and `Lexxy.configure({ name: {...} })` |
| `<lexxy-prompt>` | Trigger-based popover (`#`, `@`) for inline attachables like project/person pills |
| `<lexxy-prompt-item>` | Suggestion row with `<template type="menu">` and `<template type="editor">` |
| Attachments | Active Storage blobs (file uploads) and custom attachables (project/person pills) |
| Custom events | `lexxy:change`, `lexxy:file-accept`, `lexxy:editor-initialized`, `lexxy:upload-*` |
| Extension | A `LexxyExtension` subclass with `lexicalExtension.register(editor)` returning a cleanup function |
| Sanitization | Lexxy widens Action Text's allowed tags/attrs; Loofah is configured to allow `var()` in CSS |

## How this app uses it

- **Presets** (`app/javascript/application.js`): `inline` (no toolbar, single-line feel) for task/event bodies; `expand` (full toolbar, multi-line) for `rich_body`. Custom extensions are registered via `global.extensions` (each extension's `enabled` getter scopes it to a preset).
- **Prompts** (`app/views/bullets/_form_fields.html.erb` and the bulletable form): `#` triggers `RemoteFilterSource` at `GET /projects/suggestions?filter=…`; `@` hits `GET /people/suggestions?filter=…`. (Lexxy sends `filter`, not `q`.) `/` lists inline composer commands (type switch, attachment) via `data-action` on menu buttons.
- **Custom extensions** (`app/javascript/extensions/`): `inline_pasting.js` strips rich paste in inline editors; `prompt_actions.js` runs Stimulus commands from prompt menu items — put `data-action` on an element inside `template[type="menu"]` to invoke it instead of inserting into the editor.
- **Tag sync** (`app/models/concerns/body_tag_syncable.rb`, `projectable.rb`, `personable.rb`): on save, `apply_project_tags_from_content!` / `apply_people_tags_from_content!` walks attachables in `body` and syncs `bullet_projects` / `bullet_people` join rows.
- **Direct uploads** (`app/javascript/controllers/bullet_composer_controller.js`): intercepts `lexxy:file-accept` and routes files to Active Storage direct uploads instead of inline attachment insertion.
- **Attachment hydration** (`app/models/bullet_editor_content.rb`): `Bullet#editor_content_for_form` hydrates project/person pills for the Lexxy editor via `projects/attachable_editor` and `people/attachable_editor`.
- **Turbo morph**: the `<lexxy-editor>` web component handles disconnect/reconnect to survive Turbo Drive page morphs without losing value or focus.

## Patching guide

| Goal | Where |
|---|---|
| Editor behavior | `Lexxy.configure` + `app/javascript/extensions/*.js` |
| Attachment partial | `app/models/bullet_editor_content.rb` |
| Prompt UI | `app/views/projects/_prompt_item.html.erb`, `app/views/people/_prompt_item.html.erb` |
| Styling | Gem `lexxy.css` (tokens + editor chrome), `app/assets/stylesheets/actiontext.css` (inline preset), `attachment.css` |
| Tag sync on save | `app/models/concerns/body_tag_syncable.rb`, `projectable.rb`, `personable.rb` |
| Upstream fix | Open an issue / PR on https://github.com/basecamp/lexxy |

## Debugging

- `document.querySelector('lexxy-editor').value` — current editor HTML.
- `LexicalEditorElement.debug = true` in console — verbose logging.
- `bullet.body.body_before_type_cast` — stored Action Text HTML.
- Watch `lexxy:editor-initialized` / `lexxy:change` on the editor element.

## When NOT to use Lexxy

- You need collaborative real-time editing — Lexxy is single-user; for that look at Lexical's Yjs bindings.
- You want a no-JS editor — use plain `text_area` and Action Text without an editor.
- You need iframe-isolated editors — Lexxy assumes same-document, form-associated context.
- You need to embed in non-HTML contexts (PDFs, RSS) — strip the Action Text body down to plain text first.
