import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }

  dragover(event) {
    event.preventDefault()
    event.dataTransfer.dropEffect = "copy"
    this.element.classList.add("drag-over")
  }

  dragleave() {
    this.element.classList.remove("drag-over")
  }

  async drop(event) {
    event.preventDefault()
    this.element.classList.remove("drag-over")

    const cardId = event.dataTransfer.getData("card-id")
    if (!cardId) return

    const token = document.querySelector("meta[name='csrf-token']").content

    const response = await fetch(this.urlValue, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": token,
        "Accept": "text/vnd.turbo-stream.html"
      },
      body: JSON.stringify({ card_id: cardId })
    })

    if (response.ok) {
      const html = await response.text()
      Turbo.renderStreamMessage(html)
    }
  }
}
