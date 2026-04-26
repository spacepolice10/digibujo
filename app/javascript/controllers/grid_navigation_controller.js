import { Controller } from "@hotwired/stimulus"
import { navigateGrid } from "helpers/grid_navigation"

export default class extends Controller {
  static values = { columns: Number }
  static targets = ["item"]

  connect() {
    this.currentPosition = 0
    this.initTabindex()
  }

  navigate(event) {
    const directions = {
      ArrowLeft: "left",
      ArrowRight: "right",
      ArrowUp: "up",
      ArrowDown: "down"
    }
    const direction = directions[event.key]
    if (!direction) return

    event.preventDefault()

    const next = navigateGrid(
      this.currentPosition,
      direction,
      this.columnsValue,
      this.itemTargets.length
    )
    this.moveTo(next)
  }

  syncPosition(event) {
    const position = this.itemTargets.indexOf(event.target)
    if (position == -1) return

    this.currentPosition = position
    this.initTabindex()
  }

  moveTo(position) {
    this.currentPosition = position
    this.initTabindex()
    this.itemTargets[position]?.focus()
  }

  itemTargetConnected() {
    this.currentPosition = 0
    this.initTabindex()
  }

  itemTargetDisconnected() {
    this.initTabindex()
  }

  initTabindex() {
    const items = this.itemTargets
    if (!items.length) return
    this.currentPosition = Math.min(this.currentPosition, items.length - 1)
    items.forEach((item, index) => {
      item.setAttribute("tabindex", index == this.currentPosition ? "0" : "-1")
    })
  }
}
