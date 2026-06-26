import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    popUrl: String,
    popsOn: { type: String, default: "" },
    reviewDrop: { type: Boolean, default: false }
  }

  dragover(event) {
    event.preventDefault()
    event.dataTransfer.dropEffect = "move"
    this.element.classList.add("pop-drop--over")
  }

  dragleave(event) {
    if (this.element.contains(event.relatedTarget)) return
    this.element.classList.remove("pop-drop--over")
  }

  async drop(event) {
    event.preventDefault()
    this.element.classList.remove("pop-drop--over")

    const bulletId = event.dataTransfer.getData("bullet-id")
    const sourcePopsOn = event.dataTransfer.getData("source-pops-on")
    if (!bulletId) return

    const targetPopsOn = this.popsOnValue
    if (targetPopsOn == sourcePopsOn) return

    const frame = document.getElementById(`bullet_${bulletId}`)
    if (!frame) return

    const revert = this.#applyOptimisticMove(frame)

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
    const headers = {
      Accept: "text/vnd.turbo-stream.html",
      "X-CSRF-Token": token,
      "X-Requested-With": this.reviewDropValue ? "review-pop-drop" : "pop-drop"
    }

    const response = await fetch(this.popUrlValue, { method, headers, body }).catch(() => null)
    if (!response) {
      revert()
      return
    }
    if (response.ok) return

    revert()
    const html = await response.text().catch(() => "")
    if (html && window.Turbo) window.Turbo.renderStreamMessage(html)
  }

  #applyOptimisticMove(frame) {
    if (this.reviewDropValue) {
      const removeTarget = frame.closest(".review--bullet") || frame
      const originalParent = removeTarget.parentElement
      const originalNextSibling = removeTarget.nextSibling

      removeTarget.remove()

      return () => {
        if (originalNextSibling) {
          originalParent.insertBefore(removeTarget, originalNextSibling)
        } else {
          originalParent.appendChild(removeTarget)
        }
      }
    }

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
