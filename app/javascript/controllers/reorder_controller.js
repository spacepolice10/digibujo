import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }

  dragstart(event) {
    event.dataTransfer.effectAllowed = "move"
    this.dragging = event.currentTarget
    this.dragging.classList.add("dragging")
  }

  dragover(event) {
    event.preventDefault()
    event.dataTransfer.dropEffect = "move"

    const target = event.currentTarget
    if (target == this.dragging || target.parentNode != this.dragging.parentNode) return

    const rect = target.getBoundingClientRect()
    const mid = rect.top + rect.height / 2

    if (event.clientY < mid) {
      target.parentNode.insertBefore(this.dragging, target)
    } else {
      target.parentNode.insertBefore(this.dragging, target.nextSibling)
    }
  }

  drop(event) {
    event.preventDefault()
    this.#persist()
  }

  dragend() {
    if (this.dragging) {
      this.dragging.classList.remove("dragging")
      this.dragging = null
    }
  }

  #persist() {
    const ids = Array.from(this.element.children).map(
      el => el.dataset.reorderIdParam
    ).filter(Boolean)

    const token = document.querySelector("meta[name='csrf-token']").content

    fetch(this.urlValue, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": token,
        "Accept": "text/vnd.turbo-stream.html"
      },
      body: JSON.stringify({ positions: ids })
    })
  }
}
