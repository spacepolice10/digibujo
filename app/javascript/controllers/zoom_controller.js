import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    this.element.querySelectorAll(".rich-text-content img").forEach((img) => {
      img.style.cursor = "zoom-in";
    });
  }

  zoom(event) {
    const img = event.target.closest("img");
    if (!img) return;

    const overlay = document.createElement("div");
    overlay.className = "image-zoom-overlay";

    const zoomedImage = document.createElement("img");
    zoomedImage.src = img.src;
    zoomedImage.alt = img.alt || "";
    overlay.append(zoomedImage);

    overlay.addEventListener("click", () => overlay.remove());
    document.addEventListener(
      "keydown",
      (e) => {
        if (e.key == "Escape") overlay.remove();
      },
      { once: true },
    );

    document.body.appendChild(overlay);
  }
}
