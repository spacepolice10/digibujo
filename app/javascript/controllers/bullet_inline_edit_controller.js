import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    this.frame = this.element.closest("turbo-frame");
    this.onPointerDown = this.onPointerDown.bind(this);
    document.addEventListener("pointerdown", this.onPointerDown, true);
  }

  disconnect() {
    document.removeEventListener("pointerdown", this.onPointerDown, true);
  }

  onPointerDown(event) {
    if (this.frame?.contains(event.target)) return;
    if (event.target.closest("[popover], dialog")) return;

    this.dismiss();
  }

  dismiss() {
    this.element.querySelector("form")?.requestSubmit();
  }
}
