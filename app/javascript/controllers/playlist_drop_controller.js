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

    const bulletId = event.dataTransfer.getData("bullet-id")
    console.log("[playlist-drop] drop fired, bulletId:", bulletId, "url:", this.urlValue)
    if (!bulletId) return

    const token = document.querySelector("meta[name='csrf-token']").content

    const response = await fetch(this.urlValue, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": token,
        "Accept": "text/vnd.turbo-stream.html"
      },
      body: JSON.stringify({ bullet_id: bulletId })
    })

    console.log("[playlist-drop] response status:", response.status, response.ok)
    if (response.ok) {
      const html = await response.text()
      console.log("[playlist-drop] turbo stream html length:", html.length)
      Turbo.renderStreamMessage(html)
    }
  }
}
