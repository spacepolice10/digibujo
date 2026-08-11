import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { mode: { type: String, default: "editor" } }
  static targets = ["form"]

  submit(event) {
    event.preventDefault()
    this.formTarget.requestSubmit()
  }

  toggleMode(event) {
    event.preventDefault()
    const mode = event.params.mode
    if (mode != this.modeValue) this.#setMode(mode)
  }

  restore(event) {
    if (!event.detail.success) return

    this.#setMode("editor")
    this.dispatch("restore")
  }

  #setMode(mode) {
    this.modeValue = mode
    this.dispatch("mode-change", { detail: { mode } })
  }
}
