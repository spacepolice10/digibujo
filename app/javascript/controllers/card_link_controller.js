import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    dragging: { type: Boolean, default: false }
  }

  mousedown(event) {
    this.downX = event.clientX
    this.downY = event.clientY
    this.draggingValue = false
  }

  mouseup() {
    if (this.hasSelectionInside()) this.draggingValue = true
  }

  click(event) {
    if (this.pointerMoved(event)) this.draggingValue = true

    if (!this.draggingValue && !this.hasSelectionInside()) return

    event.preventDefault()
    this.draggingValue = false
  }

  pointerMoved(event) {
    if (this.downX == null || this.downY == null) return false

    const threshold = 3
    return Math.abs(event.clientX - this.downX) > threshold || Math.abs(event.clientY - this.downY) > threshold
  }

  hasSelectionInside() {
    const selection = window.getSelection()
    if (!selection || selection.isCollapsed) return false

    const startsInside = selection.anchorNode && this.element.contains(selection.anchorNode)
    const endsInside = selection.focusNode && this.element.contains(selection.focusNode)
    return startsInside || endsInside
  }
}
