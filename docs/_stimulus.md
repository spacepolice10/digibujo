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

- `app/javascript/controllers/index.js` — eager-loads `timezone-cookie` (needed on every page); lazy-loads everything else via `@hotwired/stimulus-loading`.
- File naming: `app/javascript/controllers/{name}_controller.js`, exported as default class.
- Registration is automatic: every `*_controller.js` in the folder becomes `data-controller="{name}"`.

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

## Conventions in this app

- **Use `==` not `===`** for equality (project convention; see `AGENTS.md`).
- **One controller owns selection state**: `bulk-menu` owns `idListValue: Array` and syncs it into every form's `data-bulk-menu-target="idList"` hidden field via `idListTargetConnected` + `idListValueChanged`. Other controllers don't read it directly.
- **Use Turbo events to close flows**, not custom events: `data-action="turbo:submit-end->dialog#submitEnd"`.
- **Lazy loading is the default**: only eager-load controllers that must run on every page (currently just `timezone-cookie`).
- **No CSS framework**: controllers toggle classes defined in component-scoped stylesheets (`*.css`).

## Digibujo controllers

| Controller | Purpose |
|---|---|
| `bullet-composer` | Lexxy file-accept interceptor; direct upload via `DirectUpload`; type-select UI (Task/Note/Event); form reset on `turbo:submit-end` success |
| `bulk-menu` | Sticky bulk-action menu; keeps `idListValue: Array`; syncs CSV to every form's hidden `idList` target; opens popover pickers; clears on visit |
| `bullet-drag` | Native HTML5 dragstart/dragend for bullets |
| `combobox` | Accessible combobox behavior |
| `daylog` | Daylog page glue |
| `dialog` | `<dialog>` open/close via `commandfor`/`command` (with click fallback) + strips `open` from cached snapshots |
| `dropdown` | Generic dropdown menu |
| `grid-navigation` | Arrow-key grid navigation |
| `hotkey` | Document-wide hotkeys (`data-hotkey="cmd+k"`); ignores inputs, contenteditable, lexxy-editor |
| `menu` | Menu shell |
| `monthly-bucket-drop` | Drop target for monthly bucket |
| `pagination` | Geared pagination |
| `scroll` | Scroll position tracking |
| `search` | Search field behavior |
| `section` | Section open/close persistence |
| `timezone-cookie` | Sets timezone cookie (eager-loaded) |
| `toasts` | Toast queue |
| `zoom` | Pinch/scroll zoom |

## Patterns to copy

- **Pair `connect` / `disconnect` listeners** — see `app/javascript/controllers/hotkey_controller.js`.
  ```javascript
  connect() {
    this._onKeydown = this.#onKeydown.bind(this)
    document.addEventListener("keydown", this._onKeydown)
  }
  disconnect() {
    document.removeEventListener("keydown", this._onKeydown)
  }
  ```

- **Document-wide event delegation via Stimulus** with matching `removeEventListener` in `disconnect` — see `bulk_menu_controller.js` and `dialog_controller.js`.

- **Popovers backed by lazy turbo-frames** (controller sets `src` and calls `showPopover()`) — see `bulk_menu_controller.js` + `docs/_turbo.md`.

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
