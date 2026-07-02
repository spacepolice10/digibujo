import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["rail"]

  connect() {
    this.syncKeyboardOffset = this.#syncKeyboardOffset.bind(this)

    if (this.element.showModal) this.element.showModal()

    window.visualViewport?.addEventListener("resize", this.syncKeyboardOffset)
    window.visualViewport?.addEventListener("scroll", this.syncKeyboardOffset)
    this.#syncKeyboardOffset()

    this.element.querySelector("lexxy-editor")?.focus()
  }

  disconnect() {
    window.visualViewport?.removeEventListener("resize", this.syncKeyboardOffset)
    window.visualViewport?.removeEventListener("scroll", this.syncKeyboardOffset)
  }

  #syncKeyboardOffset() {
    const viewport = window.visualViewport
    if (!viewport) return

    const offset = Math.max(0, window.innerHeight - viewport.height - viewport.offsetTop)
    this.element.style.setProperty("--bullet-composer-keyboard-offset", `${offset}px`)
  }
}
