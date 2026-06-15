import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    popUrl: String,
    popsOn: { type: String, default: "" }
  }

  dragover(event) {
    event.preventDefault()
    event.dataTransfer.dropEffect = "move"
    this.element.classList.add("monthly-bucket--drop-over")
  }

  dragleave(event) {
    if (this.element.contains(event.relatedTarget)) return
    this.element.classList.remove("monthly-bucket--drop-over")
  }

  async drop(event) {
    event.preventDefault()
    this.element.classList.remove("monthly-bucket--drop-over")

    const bulletId = event.dataTransfer.getData("bullet-id")
    const sourcePopsOn = event.dataTransfer.getData("source-pops-on")
    if (!bulletId) return

    const targetPopsOn = this.popsOnValue
    if (targetPopsOn == sourcePopsOn) return

    const body = new FormData()
    body.append("bullet_ids", bulletId)

    let method
    if (targetPopsOn) {
      method = "POST"
      body.append("pops_on", targetPopsOn)
    } else {
      method = "DELETE"
      body.append("pops_on", "")
    }

    const token = document.querySelector("meta[name='csrf-token']")?.content
    const response = await fetch(this.popUrlValue, {
      method,
      headers: {
        Accept: "text/vnd.turbo-stream.html",
        "X-CSRF-Token": token,
        "X-Requested-With": "monthly-bucket-drop"
      },
      body
    }).catch(() => null)

    if (!response) return

    if (response.ok) {
      const frame = document.getElementById(`bullet_${bulletId}`)
      if (frame) this.element.appendChild(frame)
      return
    }

    const html = await response.text().catch(() => "")
    if (html && window.Turbo) window.Turbo.renderStreamMessage(html)
  }
}
