import { Controller } from "@hotwired/stimulus";
import { patch } from "@rails/request.js";

export default class extends Controller {
  static values = {
    url: String
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
    if (!this.hasUrlValue) return;

    // @rails/request.js sets Content-Type to application/json unless the body
    // is a FormData. A plain URLSearchParams gets the wrong Content-Type and
    // Rails would try to JSON-parse it, so we use FormData to let the browser
    // set the correct multipart Content-Type and let Rails parse normally.
    const formData = new FormData();
    formData.append("open", open ? "true" : "false");
    patch(this.urlValue, { body: formData }).catch(() => {});
  }
}
