import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  click(event) {
    if (this.#isClickable && !this.#shouldIgnore(event)) {
      event.preventDefault();
      this.element.click();
    }
  }

  focus(event) {
    if (this.#isClickable && !this.#shouldIgnore(event)) {
      event.preventDefault();
      this.element.focus();
    }
  }

  #shouldIgnore(event) {
    if (event.defaultPrevented) return true;

    const typing = event.target.closest(
      "textarea, [contenteditable], lexxy-editor, .lexxy-editor__content",
    );
    if (typing) return true;

    const field = event.target.closest("input, select");
    if (!field) return false;

    return field.type != "checkbox" && field.type != "radio";
  }

  get #isClickable() {
    if (this.element.closest("[hidden]")) return false;

    return getComputedStyle(this.element).pointerEvents !== "none";
  }
}
