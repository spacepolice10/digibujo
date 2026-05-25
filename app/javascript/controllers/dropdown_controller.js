import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    this.onClick = this.onClick.bind(this);
    document.addEventListener("click", this.onClick);
  }

  disconnect() {
    document.removeEventListener("click", this.onClick);
  }

  hide(event) {
    if (!this.element.contains(event.target)) {
      this.element.removeAttribute("open");
    }
  }
}
