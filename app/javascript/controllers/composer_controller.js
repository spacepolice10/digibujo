import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { filled: Boolean, locked: Boolean }
  static targets = ["form"]

  submit(event) {
    event.preventDefault()
    if (this.filledValue) this.formTarget.requestSubmit()
  }

  lock() {
    this.lockedValue = true
    this.filledValue = true
  }

  unlock() {
    this.lockedValue = false
  }

  sync(event) {
    this.filledValue = !event.currentTarget.isBlank
  }

  restore(event) {
    if (!event.detail.success) return

    this.filledValue = false
    this.dispatch("restore")
  }
}
