import { Controller } from "@hotwired/stimulus"

const TYPE_SHORTCUTS = { "* ": "task", "- ": "note" }

export default class extends Controller {
  static values = { type: String }
  static targets = ["fieldsFrame", "cardTypeButton", "cardableTypeField"]

  connect() {
    this.element.dataset.loading = ""
    requestAnimationFrame(() => requestAnimationFrame(() => {
      delete this.element.dataset.loading
    }))
  }

  selectType(event) {
    this.typeValue = event.currentTarget.dataset.value
  }

  typeValueChanged(value) {
    this.cardTypeButtonTargets.forEach(b => b.classList.toggle("active", b.dataset.value == value))
    this.element.classList.toggle("type-selected", !!value)

    if (this.hasCardableTypeFieldTarget) {
      this.cardableTypeFieldTarget.value = value
    }

    if (this.hasFieldsFrameTarget) {
      if (value) {
        this.fieldsFrameTarget.src = `/cards/cardable_types/${value}`
      } else {
        this.fieldsFrameTarget.removeAttribute("src")
        this.fieldsFrameTarget.innerHTML = ""
      }
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
