import { Controller } from "@hotwired/stimulus"
import { post } from "@rails/request.js"

export default class extends Controller {
  static values = {
    popsUrl: { type: String, default: "/bullets/postpone" },
    popsOn: { type: String, default: "" },
    bucketId: { type: String, default: "" },
    requestedWith: { type: String, default: "pops-drop" }
  }

  dragover(event) {
    event.preventDefault()
    event.dataTransfer.dropEffect = "move"
    this.element.classList.add("pops-drop--over")
  }

  dragleave(event) {
    if (this.element.contains(event.relatedTarget)) return
    this.element.classList.remove("pops-drop--over")
  }

  async drop(event) {
    event.preventDefault()
    this.element.classList.remove("pops-drop--over")

    const bulletId = event.dataTransfer.getData("bullet-id")
    const sourceZone = event.dataTransfer.getData("source-zone")
    if (!bulletId) return

    const targetPopsOn = this.popsOnValue
    if (targetPopsOn == sourceZone) return

    const frame = document.getElementById(`bullet_${bulletId}`)
    if (!frame) return

    const revert = this.#optimisticMove(frame)

    const body = new FormData()
    body.append("bullet_ids", bulletId)
    body.append("bucket_id", this.bucketIdValue)
    body.append("pops_on", targetPopsOn || "")

    try {
      const response = await post(this.popsUrlValue, {
        body,
        responseKind: "turbo-stream",
        headers: {
          "X-Requested-With": this.requestedWithValue
        }
      })

      if (response.ok) return

      revert?.()
      if (!response.unprocessableEntity && response.isTurboStream) {
        await response.renderTurboStream()
      }
    } catch {
      revert?.()
    }
  }

  #optimisticMove(frame) {
    if (this.requestedWithValue == "review-pops-drop") return null

    const optimistic = this.application.getControllerForElementAndIdentifier(
      this.element,
      "drop-postpone-optimistic"
    )
    return optimistic?.move(frame) ?? null
  }
}
