import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["hiddenMood", "text", "option", "clearButton"]
  static values = {
    mood: { type: String, default: "" }
  }

  connect() {
    this.reset()
  }

  moodValueChanged() {
    this._updateDisplay()
  }

  reset() {
    this.moodValue = this.hiddenMoodTarget.value || ""
  }

  select(event) {
    const { mood } = event.currentTarget.dataset
    this.moodValue = mood
  }

  clear() {
    this.moodValue = ""
  }

  save() {
    this.hiddenMoodTarget.value = this.moodValue
    this._updateDisplay()
    this.element.querySelector("dialog").close()
  }

  cancel() {
    this.reset()
    this.element.querySelector("dialog").close()
  }

  _updateDisplay() {
    const selected = this.moodValue
    this.clearButtonTarget.disabled = !selected
    this.optionTargets.forEach(el => {
      const isActive = el.dataset.mood == selected
      el.classList.toggle("is-active", isActive)
      el.setAttribute("aria-pressed", isActive)
    })

    if (selected) {
      this.textTarget.textContent = `Mood: ${selected.charAt(0).toUpperCase()}${selected.slice(1)}`
    } else {
      this.textTarget.textContent = "Mood"
    }
  }
}
