import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  move(frame) {
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
