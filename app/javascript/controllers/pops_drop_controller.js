import { Controller } from "@hotwired/stimulus"
import { post } from "@rails/request.js"

export default class extends Controller {
  static values = {
    popsUrl: { type: String, default: "/bullets/postpone" },
    popsOn: { type: String, default: "" },
    bucketId: { type: String, default: "" },
    reviewDrop: { type: Boolean, default: false }
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

    const revert = this.reviewDropValue ? null : this.#applyOptimisticMove(frame)

    const body = new FormData()
    body.append("bullet_ids", bulletId)
    body.append("bucket_id", this.bucketIdValue)
    body.append("pops_on", targetPopsOn || "")

    try {
      const response = await post(this.popsUrlValue, {
        body,
        responseKind: "turbo-stream",
        headers: {
          "X-Requested-With": this.reviewDropValue ? "review-pops-drop" : "pops-drop"
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

  #applyOptimisticMove(frame) {
    const originalParent = frame.parentElement
    const originalNextSibling = frame.nextSibling

    const composer = this.element.querySelector("turbo-frame[id^='composer_']")
    if (composer) {
      composer.before(frame)
    } else {
      this.element.appendChild(frame)
    }

    return () => {
      if (originalNextSibling) {
        originalParent.insertBefore(frame, originalNextSibling)
      } else {
        originalParent.appendChild(frame)
      }
    }
  }
}
