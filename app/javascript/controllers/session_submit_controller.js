import { Controller } from "@hotwired/stimulus"

// Sets aria-busy on the Continue button for the duration of a Turbo submit.
export default class extends Controller {
  static targets = ["button"]

  connect() {
    this.element.addEventListener("turbo:submit-start", this.#busy)
    this.element.addEventListener("turbo:submit-end", this.#idle)
  }

  disconnect() {
    this.element.removeEventListener("turbo:submit-start", this.#busy)
    this.element.removeEventListener("turbo:submit-end", this.#idle)
  }

  #busy = () => {
    if (!this.hasButtonTarget) return

    this.buttonTarget.disabled = true
    this.buttonTarget.setAttribute("aria-busy", "true")
  }

  #idle = (event) => {
    if (!this.hasButtonTarget) return
    // Successful submit navigates away; only reset on validation errors.
    if (event.detail?.success) return

    this.buttonTarget.disabled = false
    this.buttonTarget.removeAttribute("aria-busy")
  }
}
