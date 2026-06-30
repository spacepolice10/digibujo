import { Controller } from "@hotwired/stimulus";
import { post } from "@rails/request.js";

export default class extends Controller {
  static values = {
    expandUrl: String,
    collapseUrl: String
  };

  preventToggle(event) {
    event.stopPropagation();
  }

  onToggle() {
    this.persist(this.element.open);
  }

  persist(open) {
    const url = open ? this.expandUrlValue : this.collapseUrlValue;
    if (!url) return;

    post(url).catch((error) => console.error("Section persist failed:", error));
  }
}
