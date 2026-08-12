import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { mode: { type: String, default: "editor" } }
  static targets = ["form", "recorderButton"]

  submit(event) {
    event.preventDefault()
    this.formTarget.requestSubmit()
  }

  toggleMode(event) {
    event.preventDefault()
    const mode = event.params.mode
    if (mode != this.modeValue) this.#changeMode(mode)
  }

  toggleRecorderButton(event) {
    if (!this.hasRecorderButtonTarget) return

    this.recorderButtonTarget.hidden = !event.currentTarget.isBlank
  }

  restore(event) {
    if (!event.detail.success) return

    this.#changeMode("editor")
    if (this.hasRecorderButtonTarget) this.recorderButtonTarget.hidden = false
    this.dispatch("restore")
  }

  #changeMode(mode) {
    this.modeValue = mode
    this.dispatch("mode-change", { detail: { mode } })
  }
}
