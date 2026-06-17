import { Controller } from "@hotwired/stimulus";
import { post } from "@rails/request.js";

export default class extends Controller {
  static values = {
    expandUrl: String,
    collapseUrl: String
  };

  connect() {
    this.onToggle = this.onToggle.bind(this);
    this.element.addEventListener("toggle", this.onToggle);
  }

  disconnect() {
    this.element.removeEventListener("toggle", this.onToggle);
  }

  showMore(event) {
    event.stopPropagation();
  }

  onToggle() {
    this.persist(this.element.open);
  }

  persist(open) {
    const url = open ? this.expandUrlValue : this.collapseUrlValue;
    if (!url) return;

    const formData = new FormData();
    formData.append("open", open ? "true" : "false");
    post(url, { body: formData }).catch((error) => console.error("Section persist failed:", error));
  }
}
