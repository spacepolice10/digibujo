import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.highlight()
    this.boundHighlight = this.highlight.bind(this)
    document.addEventListener("turbo:load", this.boundHighlight)
  }

  disconnect() {
    document.removeEventListener("turbo:load", this.boundHighlight)
  }

  highlight() {
    const current = window.location.pathname
    this.element.querySelectorAll("a[href]").forEach(link => {
      link.classList.toggle("streams-type-item--active", link.pathname == current)
    })
  }
}
