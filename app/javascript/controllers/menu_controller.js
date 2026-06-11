import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["focus"];

  focusOnOpen(event) {
    if (!event.target.open) return;
    this._focus();
  }

  open(event) {
    event.preventDefault();
    if (!this.element.open) this.element.setAttribute("open", "");
    this._focus();
  }

  _focus() {
    requestAnimationFrame(() => {
      this.focusTarget?.focus();
    });
  }
}
