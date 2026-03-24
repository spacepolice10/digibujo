import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["readView", "editView", "editBtn", "cancelBtn"]

  #activateTimer = null

  activate(event) {
    if (this.readViewTarget.hidden) return                                     // already editing
    if (event.target.closest("a")) return                                      // let links navigate normally
    if (event.target.closest("action-text-attachment, figure")) return         // files and image attachments

    // Capture click position before the DOM changes
    const x = event.clientX
    const y = event.clientY

    // Debounce: cancel any pending activation (e.g. first click of a double-click)
    clearTimeout(this.#activateTimer)
    this.#activateTimer = setTimeout(() => {
      if (window.getSelection().toString()) return                             // text selected — user was double-clicking to select
      this.#doActivate(x, y)
    }, 300)
  }

  #doActivate(x, y) {
    // 1. Compute char offset in read view DOM before swap
    const charOffset = this.#caretCharOffset(x, y)

    // 2. Swap views + nav buttons
    this.readViewTarget.hidden = true
    this.editViewTarget.hidden = false
    this.#toggleNav(true)

    // 3. Focus Trix and place cursor
    const trix = this.editViewTarget.querySelector("trix-editor")
    if (trix.editor) {
      this.#setCursor(trix, charOffset)
    } else {
      trix.addEventListener("trix-initialize", () => this.#setCursor(trix, charOffset), { once: true })
    }
  }

  deactivate() {
    clearTimeout(this.#activateTimer)
    this.readViewTarget.hidden = false
    this.editViewTarget.hidden = true
    this.#toggleNav(false)
  }

  #caretCharOffset(x, y) {
    let node, offset
    if (document.caretRangeFromPoint) {
      const r = document.caretRangeFromPoint(x, y)
      if (r) { node = r.startContainer; offset = r.startOffset }
    } else if (document.caretPositionFromPoint) {
      const p = document.caretPositionFromPoint(x, y)
      if (p) { node = p.offsetNode; offset = p.offset }
    }
    if (!node) return 0
    try {
      const range = document.createRange()
      range.setStart(this.readViewTarget, 0)
      range.setEnd(node, offset)
      return range.toString().length
    } catch { return 0 }
  }

  #setCursor(trix, charOffset) {
    trix.focus()
    requestAnimationFrame(() => {
      trix.editor.setSelectedRange([charOffset, charOffset])
    })
  }

  #toggleNav(editing) {
    this.editBtnTarget.hidden = editing
    this.cancelBtnTarget.hidden = !editing
  }
}
