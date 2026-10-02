import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["editor"]

  submitByKeyboard(event) {
    event.stopPropagation()
    event.stopImmediatePropagation()
    const metaReturn = event.key == "Enter" && (event.metaKey || event.ctrlKey)
    const justReturn = event.keyCode == 13 && !event.shiftKey && !event.isComposing
    if (!this.#coarsePointer && (metaReturn || justReturn)) {
      event.preventDefault()
      this.dispatch("submit")
    }
  }

  restore() {
    this.editorTarget.value = ""
    if (this.#coarsePointer) return
    this.editorTarget.focus()
  }

  get #coarsePointer() {
    return "ontouchstart" in window || navigator.maxTouchPoints > 0 || navigator.msMaxTouchPoints > 0
  }
}
