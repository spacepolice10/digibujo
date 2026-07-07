import { Controller } from "@hotwired/stimulus"
import { post } from "@rails/request.js"

export default class extends Controller {
  static values = {
    collectUrl: { type: String, default: "/bullets/collect" },
    bucketId: Number
  }

  dragover(event) {
    event.preventDefault()
    event.dataTransfer.dropEffect = "move"
    this.element.classList.add("collect-drop--over")
  }

  dragleave(event) {
    if (this.element.contains(event.relatedTarget)) return
    this.element.classList.remove("collect-drop--over")
  }

  async drop(event) {
    event.preventDefault()
    this.element.classList.remove("collect-drop--over")

    const bulletId = event.dataTransfer.getData("bullet-id")
    if (!bulletId) return

    const frame = document.getElementById(`bullet_${bulletId}`)
    if (!frame) return

    const revert = this.#removeOptimistically(frame)

    const body = new FormData()
    body.append("bullet_ids", bulletId)
    body.append("bucket_id", this.bucketIdValue)

    try {
      const response = await post(this.collectUrlValue, {
        body,
        responseKind: "turbo-stream"
      })
      if (response.ok) return

      revert()
      if (!response.unprocessableEntity && response.isTurboStream) {
        await response.renderTurboStream()
      }
    } catch {
      revert()
    }
  }

  #removeOptimistically(frame) {
    const originalParent = frame.parentElement
    const originalNextSibling = frame.nextSibling

    frame.remove()

    return () => {
      if (originalNextSibling) {
        originalParent.insertBefore(frame, originalNextSibling)
      } else {
        originalParent.appendChild(frame)
      }
    }
  }
}
