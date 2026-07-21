import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  move(frame) {
    const originalParent = frame.parentElement
    const originalNextSibling = frame.nextSibling

    // Drop target is this.element — same node that carries data-drop-zone-value
    this.element.appendChild(frame)

    return () => {
      if (originalNextSibling) {
        originalParent.insertBefore(frame, originalNextSibling)
      } else {
        originalParent.appendChild(frame)
      }
    }
  }
}
