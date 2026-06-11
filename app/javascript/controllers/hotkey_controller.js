import { Controller } from "@hotwired/stimulus";

const MODIFIER_ALIASES = {
  shift: "shift",
  ctrl: "ctrl",
  control: "ctrl",
  meta: "meta",
  cmd: "meta",
  command: "meta",
  alt: "alt",
  option: "alt",
};

const DIGIT_CODES = Object.fromEntries(
  "0123456789".split("").map((digit) => [digit, `Digit${digit}`]),
);

export default class extends Controller {
  connect() {
    this._onKeydown = this.#onKeydown.bind(this);
    document.addEventListener("keydown", this._onKeydown);
  }

  disconnect() {
    document.removeEventListener("keydown", this._onKeydown);
  }

  #onKeydown(event) {
    if (!this.#isClickable || this.#shouldIgnore(event)) return;
    if (!this.#bindings.some((binding) => this.#matches(event, binding))) return;

    event.preventDefault();
    this.element.click();
  }

  get #bindings() {
    const raw = this.element.dataset.hotkeyBindings || this.element.dataset.hotkey;
    if (!raw) return [];

    return raw.split(/\s+/).filter(Boolean);
  }

  #matches(event, chord) {
    const tokens = chord.split("+").map((token) => token.trim());
    if (!tokens.length) return false;

    const key = tokens.pop();
    const modifiers = new Set(
      tokens
        .map((token) => MODIFIER_ALIASES[token.toLowerCase()])
        .filter(Boolean),
    );

    if (event.shiftKey != modifiers.has("shift")) return false;
    if (event.ctrlKey != modifiers.has("ctrl")) return false;
    if (event.metaKey != modifiers.has("meta")) return false;
    if (event.altKey != modifiers.has("alt")) return false;

    const digitCode = DIGIT_CODES[key];
    if (digitCode) return event.code == digitCode;

    if (key.length == 1 && /[a-zA-Z]/.test(key)) {
      return event.code == `Key${key.toUpperCase()}`;
    }

    return false;
  }

  #shouldIgnore(event) {
    return event.defaultPrevented ||
      event.target.closest("input, textarea, [contenteditable], lexxy-editor, .lexxy-editor__content");
  }

  get #isClickable() {
    return getComputedStyle(this.element).pointerEvents !== "none";
  }
}
