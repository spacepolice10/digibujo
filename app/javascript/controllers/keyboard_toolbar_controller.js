import { Controller } from "@hotwired/stimulus"

// Sets --keyboard-offset CSS custom property on the controller element,
// reflecting the current software keyboard height in pixels. Also sets
// data-keyboard="visible" when a keyboard is detected, so CSS can
// conditionally toggle safe-area-inset padding.
//
// Usage:
//   <div data-controller="keyboard-toolbar">
//     <div style="bottom: var(--keyboard-offset, 0px)">toolbar</div>
//   </div>
//
// Works via the Visual Viewport API. Falls back gracefully (offset stays 0).

const KEYBOARD_THRESHOLD = 100

export default class extends Controller {
  connect() {
    this.update = this.update.bind(this)

    if (window.visualViewport) {
      window.visualViewport.addEventListener("resize", this.update)
      window.visualViewport.addEventListener("scroll", this.update)
    }

    this.update()
  }

  disconnect() {
    if (window.visualViewport) {
      window.visualViewport.removeEventListener("resize", this.update)
      window.visualViewport.removeEventListener("scroll", this.update)
    }
  }

  update() {
    const vv = window.visualViewport
    if (!vv) return

    const offset = Math.max(0, window.innerHeight - vv.height - vv.offsetTop)
    this.element.style.setProperty("--keyboard-offset", `${offset}px`)

    if (offset > KEYBOARD_THRESHOLD) {
      this.element.dataset.keyboard = "visible"
    } else {
      delete this.element.dataset.keyboard
    }
  }
}
