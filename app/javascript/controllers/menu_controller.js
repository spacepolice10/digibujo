import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["focus"];

  connect() {
    this.onDocumentFocusIn = this.onDocumentFocusIn.bind(this);
    document.addEventListener("focusin", this.onDocumentFocusIn);
  }

  disconnect() {
    document.removeEventListener("focusin", this.onDocumentFocusIn);
  }

  focusOnOpen(event) {
    if (!event.target.open) return;
    this._focus();
  }

  open(event) {
    event.preventDefault();
    if (!this.element.open) this.element.setAttribute("open", "");
    this._focus();
  }

  keydown(event) {
    if (!this.element.open) return;
    if (event.key != "Tab") return;

    const focusableElements = this._focusableElements();
    if (focusableElements.length == 0) {
      event.preventDefault();
      this._focus();
      return;
    }

    const firstElement = focusableElements[0];
    const lastElement = focusableElements[focusableElements.length - 1];
    const activeElement = document.activeElement;

    if (event.shiftKey && activeElement == firstElement) {
      event.preventDefault();
      lastElement.focus();
      return;
    }

    if (!event.shiftKey && activeElement == lastElement) {
      event.preventDefault();
      firstElement.focus();
    }
  }

  onDocumentFocusIn(event) {
    if (!this.element.open) return;
    if (this.element.contains(event.target)) return;

    this._focus();
  }

  _focusableElements() {
    return Array.from(this.element.querySelectorAll("a, button, input, select, textarea, summary, [tabindex]")).filter((element) => {
      if (element.hasAttribute("disabled")) return false;
      if (element.getAttribute("tabindex") == "-1") return false;
      if (element.hidden) return false;

      return true;
    });
  }

  _focus() {
    requestAnimationFrame(() => {
      if (!this.element.open) return;

      this.focusTarget?.focus();
    });
  }
}
