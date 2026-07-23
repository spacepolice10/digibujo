import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  openOnFrame(event) {
    if (!this.#frameEventForComposer(event)) return

    this.#ensureOpen()
  }

  openOnFrameLoad(event) {
    if (!this.#frameEventForComposer(event)) return

    this.#ensureOpen()
  }

  async cleanupElement() {
    await Promise.all(
      this.element.getAnimations().map((animation) => animation.finished.catch(() => {}))
    )

    this.element.querySelectorAll("turbo-frame").forEach((frame) => {
      frame.removeAttribute("src")
      frame.innerHTML = ""
    })
  }

  #frameEventForComposer(event) {
    if (!(event.target instanceof Element)) return false
    if (event.target.tagName != "TURBO-FRAME") return false

    return this.element.contains(event.target)
  }

  #ensureOpen() {
    const dialog = this.element
    if (dialog.open) return

    try {
      dialog.showModal()
    } catch (error) {
      if (error.name != "InvalidStateError") throw error

      dialog.close()
      dialog.showModal()
    }
  }
}
