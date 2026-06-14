import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["previews"];

  handleKeydown(event) {
    if (event.isComposing) return;

    if (event.key == "Enter") {
      event.preventDefault();
      this.element.requestSubmit();
    }
  }
}
