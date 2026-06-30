import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  zoom() {
    if (this.element.classList.contains("attachment--zoomed")) {
      this.close();
      return;
    }

    this.element.classList.add("attachment--zoomed");

    this.backdrop = document.createElement("div");
    this.backdrop.className = "zoom-overlay";
    this.backdrop.addEventListener("click", this.close);
    document.body.appendChild(this.backdrop);

    this.onKeydown = (event) => {
      if (event.key == "Escape") this.close();
    };
    document.addEventListener("keydown", this.onKeydown);
  }

  close = () => {
    this.element.classList.remove("attachment--zoomed");
    this.backdrop?.remove();
    this.backdrop = null;

    if (this.onKeydown) {
      document.removeEventListener("keydown", this.onKeydown);
      this.onKeydown = null;
    }
  };

  disconnect() {
    this.close();
  }
}
