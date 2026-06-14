import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["current"]

  connect() {
    if (!this.hasCurrentTarget) return

    requestAnimationFrame(() => this.scrollToCurrent())
  }

  scrollToCurrent() {
    const row = this.currentTarget
    const container = this.element

    if (container.scrollHeight > container.clientHeight) {
      const rowOffset =
        row.getBoundingClientRect().top -
        container.getBoundingClientRect().top +
        container.scrollTop
      const centered =
        rowOffset - (container.clientHeight - row.offsetHeight) / 2
      const maxScroll = container.scrollHeight - container.clientHeight

      container.scrollTop = Math.max(0, Math.min(maxScroll, centered))
    } else {
      row.scrollIntoView({ block: "center", inline: "nearest" })
    }
  }
}
