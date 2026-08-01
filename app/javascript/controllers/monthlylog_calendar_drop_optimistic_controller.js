import { Controller } from "@hotwired/stimulus"

// Same move(frame) hook as drop-postpone-optimistic, for calendar cells:
// detach bullet from source list, ±1 count on target/source cells, toggle
// indicator visibility; if open monthlylog_date matches this pops_on, append there.
export default class extends Controller {
  static targets = ["indicator"]
  static values = { count: { type: Number, default: 0 } }

  countValueChanged() {
    this.#syncIndicator()
  }

  move(frame) {
    const originalParent = frame.parentElement
    const originalNextSibling = frame.nextSibling
    const sourceZone =
      originalParent?.closest("[data-drop-zone-value]")?.dataset.dropZoneValue ?? ""
    const targetZone = this.element.dataset.dropZoneValue ?? ""

    frame.remove()

    const datePanel = document.getElementById("monthlylog_date")
    const panelZone = datePanel?.dataset.popsOn ?? ""
    const list = datePanel?.querySelector("[data-monthlylog-date-list]")
    let appendedToPanel = false

    if (list && panelZone && panelZone === targetZone) {
      list.appendChild(frame)
      appendedToPanel = true
    }

    const previousCount = this.countValue
    this.countValue = previousCount + 1

    const sourceController = this.#sourceController(sourceZone)
    const previousSourceCount = sourceController?.countValue
    if (sourceController && sourceZone !== targetZone) {
      sourceController.countValue = Math.max(0, sourceController.countValue - 1)
    }

    return () => {
      if (appendedToPanel) {
        frame.remove()
      }

      if (originalNextSibling) {
        originalParent.insertBefore(frame, originalNextSibling)
      } else {
        originalParent.appendChild(frame)
      }

      this.countValue = previousCount
      if (sourceController && previousSourceCount != null) {
        sourceController.countValue = previousSourceCount
      }
    }
  }

  #sourceController(sourceZone) {
    if (!sourceZone) return null

    const sourceCell = document.querySelector(
      `.monthlylog--date-cell[data-drop-zone-value="${CSS.escape(sourceZone)}"]`
    )
    if (!sourceCell) return null

    return this.application.getControllerForElementAndIdentifier(
      sourceCell,
      "monthlylog-calendar-drop-optimistic"
    )
  }

  #syncIndicator() {
    if (!this.hasIndicatorTarget) return

    this.indicatorTarget.hidden = this.countValue < 1
  }
}
