import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  remove(frame) {
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
