import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.onClick = this.onClick.bind(this)
    document.addEventListener("click", this.onClick)
  }

  disconnect() {
    document.removeEventListener("click", this.onClick)
  }

  onClick(event) {
    this.element.querySelectorAll("details[open]").forEach(details => {
      if (!details.contains(event.target)) {
        details.removeAttribute("open")
      }
    })
  }
}
