import { Controller } from "@hotwired/stimulus";
import { post } from "@rails/request.js";

export default class extends Controller {
  static values = {
    expandPath: String,
    collapsePath: String
  };

  onToggle() {
    this.persist(this.element.open);
  }

  persist(open) {
    const url = open ? this.expandPathValue : this.collapsePathValue;
    if (!url) return;

    post(url).catch((error) => console.error("Section persist failed:", error));
  }
}
