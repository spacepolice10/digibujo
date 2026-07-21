import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["focus"];

  focusOnOpen(event) {
    if (event.newState != "open") return;
    this.#focus();
  }

  open(event) {
    event.preventDefault();
    if (!this.#open) this.element.showPopover();
    this.#focus();
  }

  close() {
    if (this.#open) this.element.hidePopover();
  }

  keydown(event) {
    if (!this.#open) return;
    if (event.key != "Tab") return;

    const focusableElements = this.#focusableElements();
    if (focusableElements.length == 0) {
      event.preventDefault();
      this.#focus();
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

  get #open() {
    return this.element.matches(":popover-open");
  }

  #focusableElements() {
    return Array.from(this.element.querySelectorAll("a, button, input, select, textarea, [tabindex]")).filter((element) => {
      if (element.hasAttribute("disabled")) return false;
      if (element.getAttribute("tabindex") == "-1") return false;
      if (element.hidden) return false;

      return true;
    });
  }

  #focus() {
    requestAnimationFrame(() => {
      if (!this.#open) return;

      this.focusTarget?.focus();
    });
  }
}
