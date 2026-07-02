import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  zoom(event) {
    const img = event.target.closest("figure.attachment--preview img");
    if (!img) return;

    if (img.classList.contains("attachment--zoomed")) {
      this.close();
      return;
    }

    this.close();

    this.zoomedImage = img;
    img.classList.add("attachment--zoomed");

    this.backdrop = document.createElement("div");
    this.backdrop.className = "zoom-overlay";
    this.backdrop.addEventListener("click", this.close);
    document.body.appendChild(this.backdrop);

    this.onKeydown = (keydownEvent) => {
      if (keydownEvent.key == "Escape") this.close();
    };
    document.addEventListener("keydown", this.onKeydown);
  }

  close = () => {
    this.zoomedImage?.classList.remove("attachment--zoomed");
    this.zoomedImage = null;
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
