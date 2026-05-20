import { Controller } from "@hotwired/stimulus";

const DEFAULT_TYPE = "note";

export default class extends Controller {
  static targets = ["typeIcon", "typeMenu", "typeForm"];
  static values = {
    type: { type: String, default: DEFAULT_TYPE },
    types: Object,
  };

  connect() {
    this.hadContent = false;
    this.renderType();
    this._onSubmit = this.prepareSubmit.bind(this);
    this.element.addEventListener("submit", this._onSubmit);
  }

  disconnect() {
    this.element.removeEventListener("submit", this._onSubmit);
  }

  typeValueChanged() {
    this.renderType();
  }

  detectType() {
    if (this._strippingMarker) return;
    this.syncTypeFromText();
  }

  selectType(event) {
    const { type } = event.params;
    if (type) this.typeValue = type;
    event.currentTarget.closest("[popover]")?.hidePopover();
    this.focusEditor();
  }

  toggleTypeMenu() {
    this.typeMenuTarget?.focus();
  }

  submitByReturn(event) {
    event.preventDefault();
    this.element.requestSubmit();
  }

  prepareSubmit() {
    this.syncTypeFromText();
  }

  plainText() {
    const editor = this.element.querySelector("trix-editor");
    if (!editor?.editor) return "";
    return editor.editor.getDocument().toString();
  }

  syncTypeFromText() {
    const text = this.plainText();
    const match = this.leadingMarkerMatch(text);

    if (match) {
      const typeChanged = match.key != this.typeValue;
      if (typeChanged) this.typeValue = match.key;
      if (typeChanged) {
        this._strippingMarker = true;
        this.stripLeadingMarker(match.removeCount);
        this._strippingMarker = false;
      }
      return;
    }

    const trimmed = text.trim();
    if (!trimmed) {
      if (this.hadContent && this.typeValue != DEFAULT_TYPE) {
        this.typeValue = DEFAULT_TYPE;
      }
      this.hadContent = false;
      return;
    }

    this.hadContent = true;
  }

  leadingMarkerMatch(text) {
    const trimmed = text.trimStart();
    const entry = this.markerEntries().find((e) => trimmed.startsWith(e.marker));
    if (!entry) return null;

    const leadingWhitespace = text.length - trimmed.length;
    return { key: entry.key, removeCount: leadingWhitespace + entry.marker.length };
  }

  markerEntries() {
    return Object.entries(this.typesValue)
      .map(([key, config]) => ({ key, marker: config.marker }))
      .filter((entry) => entry.marker)
      .sort((a, b) => b.marker.length - a.marker.length || b.marker.localeCompare(a.marker));
  }

  stripLeadingMarker(removeCount) {
    const editor = this.element.querySelector("trix-editor");
    if (!editor?.editor || !removeCount) return;

    editor.editor.setSelectedRange([0, removeCount]);
    editor.editor.deleteInDirection("forward");
  }

  renderType() {
    const config = this.typesValue[this.typeValue];
    if (!config) return;

    if (this.hasTypeFormTarget) {
      this.typeFormTarget.value = config.bulletableType;
    }

    if (this.hasTypeIconTarget) {
      this.typeIconTarget.style.setProperty(
        "--icon-mask",
        `var(--icon-${config.icon})`,
      );
      this.typeIconTarget.style.setProperty(
        "color",
        `var(--model-color-${config.colour})`,
      );
    }

    const radio = this.element.querySelector(
      `input[name="bullet[bulletable_type]"][value="${config.bulletableType}"]`,
    );
    if (radio) radio.checked = true;
  }

  focusEditor() {
    this.element.querySelector("trix-editor")?.focus();
  }
}
