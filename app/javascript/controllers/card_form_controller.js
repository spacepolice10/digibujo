import { Controller } from "@hotwired/stimulus"

const TYPE_SHORTCUTS = { ">t": "task", ">n": "note", ">d": "draft" }

export default class extends Controller {
  static values = { type: String }
  static targets = ["datePicker", "tagPicker", "cardTypeButton", "cardableTypeField"]

  connect() {
    const first = this.cardTypeButtonTargets[0]
    if (first) this.typeValue = first.dataset.value
  }

  selectType(event) {
    this.typeValue = event.currentTarget.dataset.value
  }

  typeValueChanged(value) {
    const button = this.cardTypeButtonTargets.find(b => b.dataset.value == value)
    const caps = button ? JSON.parse(button.dataset.capabilities) : {}

    this.cardTypeButtonTargets.forEach(b => b.classList.toggle("active", b.dataset.value == value))

    if (this.hasCardableTypeFieldTarget) {
      this.cardableTypeFieldTarget.value = value
    }
    if (this.hasDatePickerTarget) {
      if (caps.temporal) {
        this.datePickerTarget.dataset.controller = "date-picker"  // stamps once; no-op on repeat
        this.datePickerTarget.hidden = false
      } else {
        this.datePickerTarget.hidden = true
        // intentionally NOT removing data-controller — keeps controller connected for fast re-show
      }
    }
    if (this.hasTagPickerTarget) {
      this.tagPickerTarget.style.display = caps.taggable ? "flex" : "none"
    }
  }

  detectTypeShortcut(event) {
    const editor = event.target.editor
    const text = editor.getDocument().toString()
    for (const [shortcut, type] of Object.entries(TYPE_SHORTCUTS)) {
      if (text.startsWith(shortcut)) {
        this.typeValue = type
        editor.setSelectedRange([0, shortcut.length])
        editor.deleteInDirection("forward")
        break
      }
    }
  }

  submitOnKeyboard(event) {
    if (event.key == "Enter" && (event.metaKey || event.ctrlKey)) {
      event.preventDefault()
      this.element.requestSubmit()
    }
  }
}
