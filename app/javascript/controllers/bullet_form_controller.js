import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["fields", "typeIcon", "typeMenu", "typeForm"];
  static values = {
    mode: String,
    type: {
      type: String,
      default: "task",
    },
    icon: {
      type: String,
      default: "square",
    },
    colour: {
      type: String,
      default: "2",
    },
  };

  typeValueChanged() {
    this.typeIconTarget.style.setProperty(
      "--icon-mask",
      `var(--icon-${this.iconValue})`,
    );
    this.typeIconTarget.style.setProperty(
      "color",
      `var(--model-color-${this.colourValue})`,
    );
  }

  connect() {
    this.typeValueChanged();
    this.updateEditorLayout();
  }

  loadFields(event) {
    const value = event.target.value;
    if (!value) return;
    this.fieldsTarget.src = `/bullets/fields/${value.toLowerCase()}`;
  }

  selectType(event) {
    this.modeValue = "picker";
    this.iconValue = event.params.icon;
    this.colourValue = event.params.colour;
    this.typeValue = event.params.type;
    event.currentTarget.closest("[popover]")?.hidePopover();
    if (this.hasTypeFormTarget) {
      const bulletableType = event.params.bulletableType;
      this.typeFormTarget.value = bulletableType || event.params.type;
    }
    this.toggleEditor();
  }

  returnToType() {
    this.modeValue = "type";
  }

  toggleTypeMenu() {
    this.typeMenuTarget.focus();
  }

  toggleEditor() {
    const editor = this.element.querySelector("trix-editor");
    if (!editor) return;
    editor.focus();
  }

  updateEditorLayout() {
    const editor = this.element.querySelector("trix-editor");
    if (!editor) return;

    let lineHeight = null;
    const parsedLineHeight = Number.parseFloat(
      window.getComputedStyle(editor).lineHeight,
    );

    if (!Number.isNaN(parsedLineHeight)) {
      lineHeight = null;
    }
    lineHeight = parsedLineHeight;
    console.log(lineHeight, parsedLineHeight);
    if (!lineHeight) return;
    const withWrappedContent = editor
      ? editor.getClientRects().length > 1
      : false;
    const withVisualOverflow = editor.scrollHeight > lineHeight * 1.5;
    const isMultiline = withWrappedContent || withVisualOverflow;

    if (isMultiline && !this._editorMultilineLocked) {
      this._editorMultilineLocked = true;
      this.element.dataset.editorMultiline = "true";
      console.log(this.element.dataset);
      console.log(this.element);
      console.log("locking");
      return;
    }

    if (this._editorMultilineLocked) {
      this.element.dataset.editorMultiline = "true";
      return;
    }

    this.element.dataset.editorMultiline = "false";
  }

  submit(event) {
    event.preventDefault();
    this.element.requestSubmit();
  }
}
