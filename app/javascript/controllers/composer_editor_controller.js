import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    type: { type: String, default: "note" },
    multiline: { type: Boolean, default: false }
  }
  static targets = ["editor", "typePicker", "toolbarToggle"]

  connect() {
    this.#observeEditorHeight()
  }

  disconnect() {
    this.resizeObserver?.disconnect()
  }

  submitByKeyboard(event) {
    event.stopPropagation()
    event.stopImmediatePropagation()
    const metaReturn = event.key == "Enter" && (event.metaKey || event.ctrlKey)
    const justReturn = event.keyCode == 13 && !event.shiftKey && !event.isComposing
    if (!this.#coarsePointer && (metaReturn || (justReturn && !this.#toolbarVisible))) {
      event.preventDefault()
      this.dispatch("submit")
    }
  }

  switchVariant(event) {
    event.preventDefault()
    event.stopPropagation()
    event.stopImmediatePropagation()

    const picker = this.typePickerTarget
    picker.selectedIndex = (picker.selectedIndex + 1) % picker.options.length
    picker.dispatchEvent(new Event("change", { bubbles: true }))
  }

  changeType(event) {
    event.preventDefault()
    this.typeValue = event.target.value
    this.toolbarToggleTarget.hidden = event.target.value != "Note"
  }

  toggleToolbar(event) {
    event.preventDefault()
    if (event.target.checked) this.#growMultiline()
      this.editorTarget.focus()
  }

  restore() {
    this.editorTarget.value = ""
    if (this.#coarsePointer) return
    this.editorTarget.focus()
  }

  #observeEditorHeight() {
    if (typeof ResizeObserver === "undefined") return
    this.resizeObserver = new ResizeObserver(() => this.#syncMultiline())
    this.resizeObserver.observe(this.editorTarget.editorContentElement ?? this.editorTarget)
  }

  #syncMultiline() {
    if (this.multilineValue) return
    if (this.#withBlockedContent()) return this.#growMultiline()

    const content = this.editorTarget.editorContentElement ?? this.editorTarget
    const height = content.offsetHeight
    if (!height) return
    if (this.editorTarget.isBlank) this.singleLineHeight = height
    if (this.singleLineHeight && height > this.singleLineHeight + 4) this.#growMultiline()
  }

  #growMultiline() {
    this.multilineValue = true
  }

  #withBlockedContent() {
    return Boolean(this.editorTarget.editorContentElement?.querySelector(
      "figure.attachment, action-text-attachment, table, ul, ol"
    ))
  }

  get #toolbarVisible() {
    return this.toolbarToggleTarget.querySelector('input[type="checkbox"]')?.checked
  }

  get #coarsePointer() {
    return "ontouchstart" in window || navigator.maxTouchPoints > 0 || navigator.msMaxTouchPoints > 0
  }
}
