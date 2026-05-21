import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    this.frame = this.element.closest("turbo-frame");
    this.abortController = new AbortController();
    document.addEventListener("pointerdown", this.dismiss.bind(this), {
      signal: this.abortController.signal,
    });
  }

  disconnect() {
    this.abortController.abort();
  }

  dismiss(event) {
    if (this.frame?.contains(event.target)) return;
    if (event.target.closest("[popover], dialog")) return;

    this.element.querySelector("form")?.requestSubmit();
  }
}
