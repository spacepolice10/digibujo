import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    this.onDocumentClick = this.onDocumentClick.bind(this);
    this.onKeydown = this.onKeydown.bind(this);
    this.onToggle = this.onToggle.bind(this);
    this.beforeVisit = this.close.bind(this);
    document.addEventListener("click", this.onDocumentClick);
    document.addEventListener("keydown", this.onKeydown);
    document.addEventListener("turbo:before-visit", this.beforeVisit);
    this.element.addEventListener("toggle", this.onToggle);
    this.syncClosedState();
  }

  disconnect() {
    document.removeEventListener("click", this.onDocumentClick);
    document.removeEventListener("keydown", this.onKeydown);
    document.removeEventListener("turbo:before-visit", this.beforeVisit);
    this.element.removeEventListener("toggle", this.onToggle);
  }

  onDocumentClick(event) {
    if (!this.element.open) return;
    if (this.element.contains(event.target)) return;

    requestAnimationFrame(() => {
      if (this.element.open && !this.element.contains(event.target)) {
        this.close();
      }
    });
  }

  onKeydown(event) {
    if (event.key == "Escape" && this.element.open) {
      event.preventDefault();
      this.close();
    }
  }

  close() {
    this.element.removeAttribute("open");
  }

  onToggle() {
    this.syncClosedState();
  }

  syncClosedState() {
    const body = this.element.querySelector(".dropdown-body");
    if (!body) return;

    body.inert = !this.element.open;

    if (this.element.open) return;

    if (body.contains(document.activeElement)) {
      this.element.querySelector("summary")?.focus();
    }
  }
}
