import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["trigger", "fallbackTriggerContent"]

  connect() {
    if (CSS.supports("appearance", "base-select")) return

    this.element.dataset.fallback = "true"
    this.triggerTarget.querySelectorAll("option[data-fallback-label]").forEach((option) => {
      option.textContent = option.dataset.fallbackLabel
    })
    this.sync()
  }

  sync() {
    if (!this.element.dataset.fallback) return

    this.fallbackTriggerContentTargets.forEach((content) => {
      content.hidden = content.dataset.value !== this.triggerTarget.value
    })
  }
}
