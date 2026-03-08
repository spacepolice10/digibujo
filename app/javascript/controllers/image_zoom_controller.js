import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.querySelectorAll(".trix-content img").forEach(img => {
      img.style.cursor = "zoom-in"
    })
  }

  zoom(event) {
    const img = event.target.closest("img")
    if (!img) return

    const overlay = document.createElement("div")
    overlay.className = "image-zoom-overlay"
    overlay.innerHTML = `<img src="${img.src}" alt="${img.alt || ""}">`
    overlay.addEventListener("click", () => overlay.remove())
    document.addEventListener("keydown", (e) => {
      if (e.key == "Escape") overlay.remove()
    }, { once: true })

    document.body.appendChild(overlay)
  }
}
