import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    mode: { type: String, default: "editor" },
    type: { type: String, default: "note" },
    multiline: { type: Boolean, default: false },
  }
  static targets = ["form", "editor", "recorder", "toolbarToggle", "submitButton"]

  connect() {
    this.#observeEditorHeight()
  }

  disconnect() {
    this.resizeObserver?.disconnect()
  }

  submit(event) {
    event.preventDefault()
    this.formTarget.requestSubmit()
  }

  submitByKeyboard(event) {
    event.stopPropagation()
    event.stopImmediatePropagation()
    const metaReturn = event.key == "Enter" && (event.metaKey || event.ctrlKey)
    const justReturn = event.keyCode == 13 && !event.shiftKey && !event.isComposing
    if (!this.#coarsePointer && (metaReturn || (justReturn && !this.#toolbarVisible))) {
      event.preventDefault()
      this.submit(event)
    }
  }

  changeType(event) {
    event.preventDefault()
    const type = event.target.value
    this.typeValue = type
    if (type == "Note") {
      this.toolbarToggleTarget.hidden = false
    } else {
      this.toolbarToggleTarget.hidden = true
    }
  }

  toggleMode(event) {
    event.preventDefault()
    const mode = event.params.mode
    this.modeValue = mode
  }

  toggleToolbar(event) {
    event.preventDefault()
    console.log(event.target.checked)
    if (event.target.checked) {
      this.#growMultiline()
    } else {
      return
    }
  }

  restoreEditor() {
    this.editorTarget.value = ""
    this.editorTarget.focus()
  }

  #observeEditorHeight() {
    if (typeof ResizeObserver === "undefined") return

    this.resizeObserver?.disconnect()
    this.resizeObserver = new ResizeObserver(() => this.#syncMultiline())
    const content = this.editorTarget.editorContentElement ?? this.editorTarget
    this.resizeObserver.observe(content)
  }


  #syncMultiline() {
    if (this.multilineValue) return

    if (this.#withBlockedContent()) {
      this.#growMultiline()
      return
    }

    const content = this.editorTarget.editorContentElement ?? this.editorTarget
    const height = content.offsetHeight
    if (!height) return

    if (this.editorTarget.isBlank) this.singleLineHeight = height
    if (!this.singleLineHeight) return

    if (height > this.singleLineHeight + 4) this.#growMultiline()
  }

  #growMultiline() {
    this.multilineValue = true
    console.log(this.multilineValue)
    console.log("growing multiline")
  }

  // A single embedded attachment, table, or list is enough to force
  // multiline chrome regardless of text height.
  #withBlockedContent() {
    return Boolean(
      this.editorTarget.editorContentElement?.querySelector(
        "figure.attachment, action-text-attachment, table, ul, ol"
      )
    )
  }

  get #toolbarVisible() {
    return this.element.querySelector(".composer--toolbar-toggle:checked")
  }

  get #coarsePointer() {
    return 'ontouchstart' in window || navigator.maxTouchPoints > 0 || navigator.msMaxTouchPoints > 0;
  }
}
