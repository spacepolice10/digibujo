import { Controller } from "@hotwired/stimulus"
import { navigateCombobox } from "helpers/combobox"

// Adds keyboard navigation to a search input + list pair.
// Arrow down/up moves the active item; Enter clicks the active item.
// Focus never leaves the input.
//
// Usage:
//   data-controller="combobox"
//   data-combobox-target="input"   → the search field
//   data-combobox-target="item"    → each list item
//   data-action="keydown->combobox#navigate" → on the input
export default class extends Controller {
  static targets = ["input", "item"]

  connect() {
    this.currentPosition = -1
  }

  navigate(event) {
    if (event.key == "ArrowDown") {
      event.preventDefault()
      this._move("down")
    } else if (event.key == "ArrowUp") {
      event.preventDefault()
      this._move("up")
    } else if (event.key == "Enter" && this.currentPosition > -1) {
      event.preventDefault()
      this.itemTargets[this.currentPosition]?.click()
    } else if (event.key == "Escape") {
      this.currentPosition = -1
      this._updateItems()
    }
  }

  itemTargetConnected() {
    this.currentPosition = -1
    this._updateItems()
  }

  itemTargetDisconnected() {
    this.currentPosition = -1
    this._updateItems()
  }

  _move(direction) {
    this.currentPosition = navigateCombobox(this.currentPosition, direction, this.itemTargets.length)
    this._updateItems()
  }

  _updateItems() {
    this.itemTargets.forEach((item, index) => {
      item.classList.toggle("is-active", index == this.currentPosition)
      item.setAttribute("aria-selected", index == this.currentPosition)
    })
  }
}
