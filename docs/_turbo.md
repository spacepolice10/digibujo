# Turbo (Hotwire)

[Turbo](https://turbo.hotwired.dev) is the page-acceleration + DOM-patching layer of Hotwire. It accelerates links, scopes page regions to frames, and lets the server push DOM updates via streams. Plus page morphs for in-place refreshes.

- **Upstream**: https://turbo.hotwired.dev/reference/drive
- **Rails guide**: https://guides.rubyonrails.org/working_with_javascript_in_rails.html
- **Reference projects**:
  - [Fizzy](https://github.com/basecamp/fizzy) — best examples of cards-as-frames and nested frame navigation.
  - [Writebook](https://github.com/basecamp/writebook) — best examples of stream actions on form submissions.
  - [Campfire](https://github.com/basecamp/campfire) — best examples of broadcast streams + Action Cable for real-time.
  - [Lexxy](https://github.com/basecamp/lexxy) — editor component handles Turbo morphing; study its disconnect/reconnect.

## The four Turbo features

| Feature | What it does | When to use |
|---|---|---|
| **Drive** | Intercepts link clicks + form submissions, fetches HTML, swaps `<body>`. | Default. Avoid full-page reloads. |
| **Frames** | Scoped navigation/updates inside a `<turbo-frame>`. Lazy-loads with `loading="lazy"`. | Bullet rows, picker popovers, search palette. |
| **Streams** | Server returns `<turbo-stream>` elements that patch the DOM by `action` + `target`. | Bulk menu actions, picks, multi-row updates. |
| **Morph** | In-place `<body>` patch preserving focus, scroll, editor state. | Set via `<meta name="turbo-refresh-method" content="morph">`. |

This app sets morph globally in `app/views/layouts/application.html.erb` so back/forward navigation preserves state.

## Conventions in this app

### Frames wrap every bullet
- `app/views/bullets/_bullet.html.erb` — every bullet is `<turbo-frame id="<%= dom_id(bullet) %>">`. This is the addressable unit for updates.
- `_turbo_stream_update.html.erb` uses `turbo_stream.replace_all bullet` to re-render the frame.
- One stream action can target one bullet without affecting the rest of the page.

### Streams for bulk actions
- `app/controllers/bullets/collects_controller.rb` — controllers always respond to `format.turbo_stream` for inline updates and `format.html` for fallback.
- Stream templates live next to the controller: `app/views/bullets/collects/create.turbo_stream.erb` iterates bullets and renders `_turbo_stream_update` for each.
- Failed actions render the same template with `status: :unprocessable_entity` so the toast frame can pick up the error.

### Popovers are lazy turbo-frames
- `app/views/bullets/_bulk_menu.html.erb` — `<turbo-frame popover loading="lazy" id="pops_picker_frame">`. The frame URL is set by `bulk-menu#openPopsPicker` and shown with `frame.showPopover()`.
- Picker content is fetched on first open only and re-used thereafter.

### Always provide HTML fallback
- Every controller returning `format.turbo_stream` also returns `format.html { redirect_back fallback_location: … }` — non-JS clients still work.
- See `bullets/collects_controller.rb` for the canonical pattern.

## Turbo events to know

| Event | When | Used by |
|---|---|---|
| `turbo:submit-end` | After a form submission finishes. `event.detail.success` indicates HTTP 2xx. | `bulk-menu#submitEnd` (clear selection), `dialog#submitEnd` (close dialog) |
| `turbo:before-visit` | Before any navigation. | `bulk-menu#clearSelection` |
| `turbo:before-render` | Before a cached snapshot is rendered. | `dialog` (strip `open` from `<dialog>` to avoid stale modals) |
| `turbo:render` / `turbo:load` | After a new body is rendered. | — |
| `turbo:frame-load` | After a `<turbo-frame>` resolves. | — |

Full list: https://turbo.hotwired.dev/reference/events

## Stream actions cheatsheet

```erb
<%# Update target's contents %>
<%= turbo_stream.update "toasts" do %>
  <%= render "shared/toasts", type: "errmsg", messages: @bullet.errors.full_messages %>
<% end %>

<%# Replace target entirely %>
<%= turbo_stream.replace bullet %>

<%# Append before/after target %>
<%= turbo_stream.append "bullets" %>
<%= turbo_stream.prepend "bullets" %>

<%# Remove target %>
<%= turbo_stream.remove "old-bullet" %>
```

`turbo_stream.replace_all` is a custom helper in this app that picks the right action based on whether the target is a turbo-frame or a plain element.

## Things to watch for

- **Morphing Lexxy editors**: the `<lexxy-editor>` web component handles disconnect/reconnect itself (see `docs/_lexxy.md`). If you add new form-associated custom elements, mirror that pattern.
- **Cached `<dialog open>`**: the `dialog` Stimulus controller strips `open` from dialogs in cached snapshots — keep that working when adding new modal flows.
- **Frame IDs must be unique on the page**: `dom_id(bullet)` is correct; don't reuse the same id on a frame and a div.
- **`data-turbo-action="advance"`** on links inside popovers will navigate — usually wrong; omit it.

## When NOT to use Turbo

- Full-page reloads are fine for marketing pages / OAuth callbacks (`data: { turbo: false }`).
- Streams alone aren't a substitute for Action Cable when you need push from arbitrary server events — pair them.
- Don't use Turbo for cross-origin navigation without explicit configuration.
