# Stimulus

[Stimulus](https://stimulus.hotwired.dev) is Hotwire's "modest JavaScript framework" — it sprinkles behavior onto HTML you already wrote, via `data-*` attributes. No virtual DOM, no client-side router, no build step.

- **Upstream**: https://stimulus.hotwired.dev/reference/controllers
- **Reference projects**:
  - [Fizzy](https://github.com/basecamp/fizzy) — best examples of Stimulus forms (composer, presence, combobox).
  - [Writebook](https://github.com/basecamp/writebook) — best examples of inline-edit controllers.
  - [Campfire](https://github.com/basecamp/campfire) — broadest catalog (message composer, search, presence, real-time).
  - [Lexxy](https://github.com/basecamp/lexxy) — the Lexxy editor itself is a custom element; read `lexical-editor-element.ts` for a complex Stimulus-adjacent pattern.

## Core concepts

| Concept | Form | Purpose |
|---|---|---|
| Controller | `data-controller="name"` | Mounts a JS class on this element and its descendants |
| Action | `data-action="event->controller#method"` | Wires DOM events to controller methods |
| Target | `data-target="controller.name"` | Typed reference: `static targets = ["name"]` → `this.nameTarget` |
| Value | `data-controller-name-value="…"` | Typed reactive value; `static values = { id: Number }` → `this.idValue` |
| Outlet | `data-controller-target="other.outlet"` | Cross-controller reference: `static outlets = ["other"]` → `this.otherOutlet` |
| Class | `static classes = […]` | Add/remove CSS classes from a typed list |

All four are declared as static class members; Stimulus wires the DOM for you. Full reference: https://stimulus.hotwired.dev/reference/attributes

## How controllers are loaded

- `app/javascript/controllers/index.js` — registers controllers with the Stimulus `application` instance; may eager-load a small set and lazy-load the rest via `@hotwired/stimulus-loading`.
- File naming: `app/javascript/controllers/{name}_controller.js`, exported as default class.
- Registration is automatic: every `*_controller.js` in the folder becomes `data-controller="{name}"` (unless manually registered under a different identifier).

## Lifecycle

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]
  static values = { url: String }

  connect()    { /* runs when element enters the DOM */ }
  disconnect() { /* runs when element leaves — always remove document listeners here */ }

  // Callback for value changes
  urlValueChanged() { }

  // Callback for target connect/disconnect
  inputTargetConnected(el) { }
  inputTargetDisconnected(el) { }
}
```

`connect()` / `disconnect()` are the only required hooks. Always pair `document.addEventListener` in `connect` with `document.removeEventListener` in `disconnect`.

## Patterns to copy

- **Document-level key filters** — chords live in the action descriptor (`keydown.ctrl+k@document->hotkey#click`), not in the controller; see Fizzy's `hotkey_controller.js` and `shared/_header.html.erb`.

- **Document-wide listeners** — bind on `document` or `window` in `connect`, remove in `disconnect`; also clear transient UI state on `blur`, `visibilitychange`, and `turbo:before-visit` when appropriate.

- **Popovers backed by lazy turbo-frames** — set the frame `src`, then `showPopover()`; see Fizzy/Campfire popover patterns and `docs/_turbo.md`.

- **Turbo events to close flows** — prefer `data-action="turbo:submit-end->dialog#submitEnd"` over custom DOM events.

- **Statics over constructors**:
  ```javascript
  static targets = ["checkbox", "idList"]
  static values = { idList: { type: Array, default: [] } }
  ```
  Always declare targets/values/outlets/classes as statics.

## When NOT to use Stimulus

- Heavy data-driven UI (tables with 10k rows, canvas) — reach for a real framework.
- State that needs to survive full page reloads — use a value backed by a hidden field, or move it server-side.
- Complex animation choreography — CSS-only is usually better.
- If you find yourself writing lots of business logic in a Stimulus controller, push it server-side and let Stimulus just be glue.
