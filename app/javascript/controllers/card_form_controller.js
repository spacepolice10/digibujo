import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["fields", "mobileFields", "mobileTypes", "typeIcon", "typeInput", "typeMenu"];
  static values = { mobileMode: String, currentType: String };

  connect() {
    if (!this.hasMobileModeValue) this.mobileModeValue = "types";
    if (!this.hasCurrentTypeValue) {
      const selectedInput = this.typeInputTargets.find((typeInput) => typeInput.checked);
      if (selectedInput) this.currentTypeValue = selectedInput.value;
    }
    this.element.dataset.mobileMode = this.mobileModeValue;
    this.element.dataset.toolbarExpanded = "false";
    if (this.hasCurrentTypeValue) this.element.dataset.currentType = this.currentTypeValue;
    this._editorMultilineLocked = this.element.dataset.editorMultiline == "true";
    this.updateEditorLayout();
  }

  loadFields(event) {
    if (!this.hasFieldsTarget) return;
    const value = event.target.value;
    if (!value) return;
    if (this.currentTypeValue == value) {
      this.element.dataset.currentType = value;
      this.updateTypeIcon(event.target);
      return;
    }

    this.currentTypeValue = value;
    this.element.dataset.currentType = value;
    this.fieldsTarget.src = `/cards/fields/${value}`;
    this.updateTypeIcon(event.target);
    this.focusEditor();
  }

  selectType(event) {
    const value = event.params.type;
    const input = this.typeInputTargets.find((typeInput) => typeInput.value == value);
    if (!input) return;

    input.checked = true;
    this.loadFields({ target: input });
    this.updateTypeIcon(input);
    this.showFields();
    event.currentTarget.closest("[popover]")?.hidePopover();
  }

  focusTypeMenu(event) {
    if (event.newState != "open") return;

    requestAnimationFrame(() => {
      const selectedInput = this.typeInputTargets.find((typeInput) => typeInput.checked);
      const selectedItem = selectedInput && this.typeMenuTarget.querySelector(
        `[data-card-form-type-param="${selectedInput.value}"]`
      );
      const fallbackItem = this.typeMenuTarget.querySelector("[data-grid-navigation-target~='item']");
      (selectedItem || fallbackItem)?.focus();
    });
  }

  toggleToolbar(event) {
    event.preventDefault();
    const expanded = this.element.dataset.toolbarExpanded == "true";
    this.element.dataset.toolbarExpanded = expanded ? "false" : "true";
    event.currentTarget.setAttribute("aria-pressed", expanded ? "false" : "true");
  }

  focusEditor() {
    const editor = this.element.querySelector("trix-editor");
    if (!editor) return;
    editor.focus();
  }

  updateEditorLayout() {
    const editor = this.element.querySelector("trix-editor");
    if (!editor) return;

    const mutable = editor.querySelector("[data-trix-mutable]");
    const lineHeight = this.parseLineHeight(window.getComputedStyle(editor).lineHeight);
    if (!lineHeight) return;

    const hasWrappedContent = mutable ? mutable.getClientRects().length > 1 : false;
    const hasVisualOverflow = editor.scrollHeight > (lineHeight * 1.5);
    const isMultiline = hasWrappedContent || hasVisualOverflow;

    if (isMultiline && !this._editorMultilineLocked) {
      this._editorMultilineLocked = true;
      this.element.dataset.editorMultiline = "true";
      return;
    }

    if (this._editorMultilineLocked) {
      this.element.dataset.editorMultiline = "true";
      return;
    }

    this.element.dataset.editorMultiline = "false";
  }

  parseLineHeight(rawLineHeight) {
    if (!rawLineHeight || rawLineHeight == "normal") return null;

    const parsed = Number.parseFloat(rawLineHeight);
    if (Number.isNaN(parsed)) return null;

    return parsed;
  }

  showFields() {
    this.mobileModeValue = "fields";
    this.element.dataset.mobileMode = "fields";
  }

  showTypes() {
    this.mobileModeValue = "types";
    this.element.dataset.mobileMode = "types";
  }

  keydown(event) {
    if (!event.ctrlKey || !event.shiftKey || event.metaKey || event.altKey) return;

    const shortcutToIndex = {
      "1": 0,
      "2": 1,
      "3": 2,
      "4": 3,
      "5": 4
    };
    const typeIndex = shortcutToIndex[event.key];
    if (typeIndex == null) return;

    const input = this.typeInputTargets[typeIndex];
    if (!input) return;

    event.preventDefault();
    input.checked = true;
    this.loadFields({ target: input });
    this.updateTypeIcon(input);
    this.showFields();
  }

  updateTypeIcon(input) {
    if (!this.hasTypeIconTarget) return;
    const icon = input.dataset.cardFormIconValue;
    if (!icon) return;
    this.typeIconTarget.style.setProperty("--icon-mask", `var(--icon-${icon})`);
  }

  submit(event) {
    event.preventDefault();
    this.element.requestSubmit();
  }
}