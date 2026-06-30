import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { id: String }

  dragstart(event) {
    event.dataTransfer.effectAllowed = "move"
    event.dataTransfer.setData("bullet-id", this.idValue)

    const zone = this.element.closest("[data-drop-zone-value]")
    const sourceZone = zone?.dataset.dropZoneValue ?? ""
    event.dataTransfer.setData("source-zone", sourceZone)

    this.element.classList.add("dragging")
  }

  dragend() {
    this.element.classList.remove("dragging")
  }
}
