import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  onDocumentClick = (event) => {
    if (!this.element.open) return;
    if (this.element.contains(event.target)) return;

    requestAnimationFrame(() => {
      if (this.element.open && !this.element.contains(event.target)) {
        this.close();
      }
    });
  };

  onKeydown = (event) => {
    if (event.key == "Escape" && this.element.open) {
      event.preventDefault();
      this.close();
    }
  };

  connect() {
    this.abortController = new AbortController()
    document.addEventListener("click", this.onDocumentClick, { signal: this.abortController.signal });
    document.addEventListener("keydown", this.onKeydown, { signal: this.abortController.signal });
  }

  disconnect() {
    this.abortController.abort()
  }

  close() {
    this.element.removeAttribute("open");
  }

  syncClosedStatusWithBody() {
    const body = this.element.querySelector(".dropdown-body");
    if (!body) return;

    body.inert = !this.element.open;

    if (this.element.open) return;

    if (body.contains(document.activeElement)) {
      this.element.querySelector("summary")?.focus();
    }
  }
}
