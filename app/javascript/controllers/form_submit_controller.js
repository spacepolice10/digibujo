import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["submit", "label", "spinner"]
  static values = { loadingText: { type: String, default: "Loading…" } }

  start() {
    if (!this.hasSubmitTarget) return

    this.submitTarget.disabled = true
    this.element.setAttribute("aria-busy", "true")

    if (this.hasLabelTarget) {
      this.originalLabel = this.labelTarget.textContent
      this.labelTarget.textContent = this.loadingTextValue
    }

    if (this.hasSpinnerTarget) {
      this.spinnerTarget.hidden = false
    }
  }

  end(event) {
    if (event.detail.success) return

    if (!this.hasSubmitTarget) return

    this.submitTarget.disabled = false
    this.element.removeAttribute("aria-busy")

    if (this.hasLabelTarget && this.originalLabel) {
      this.labelTarget.textContent = this.originalLabel
    }

    if (this.hasSpinnerTarget) {
      this.spinnerTarget.hidden = true
    }
  }
}
