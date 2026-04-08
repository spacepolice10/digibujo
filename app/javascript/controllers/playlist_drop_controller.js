import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }

  dragover(event) {
    event.preventDefault()
    event.dataTransfer.dropEffect = "move"
    this.element.classList.add("drag-over")
  }

  dragenter(event) {
    console.log("[playlist-drop] dragenter fired")
    event.preventDefault()
  }

  dragleave() {
    this.element.classList.remove("drag-over")
  }

  async drop(event) {
    console.log(event)
    event.preventDefault()
    this.element.classList.remove("drag-over")

    const cardId = event.dataTransfer.getData("card-id")
    console.log("[playlist-drop] drop fired, cardId:", cardId, "url:", this.urlValue)
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

    console.log("[playlist-drop] response status:", response.status, response.ok)
    if (response.ok) {
      const html = await response.text()
      console.log("[playlist-drop] turbo stream html length:", html.length)
      Turbo.renderStreamMessage(html)
    }
  }
}
