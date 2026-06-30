import { Controller } from "@hotwired/stimulus"

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

    const token = document.querySelector("meta[name='csrf-token']")?.content
    const response = await fetch(this.collectUrlValue, {
      method: "POST",
      headers: {
        Accept: "text/vnd.turbo-stream.html",
        "X-CSRF-Token": token
      },
      body
    }).catch(() => null)

    if (!response) {
      revert()
      return
    }
    if (response.ok) return

    revert()
    const html = await response.text().catch(() => "")
    if (html && window.Turbo) window.Turbo.renderStreamMessage(html)
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
