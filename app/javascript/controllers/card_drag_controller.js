import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { id: String }

  dragstart(event) {
    event.dataTransfer.effectAllowed = "move"
    event.dataTransfer.setData("card-id", this.idValue)
    this.element.classList.add("dragging")
  }

  dragend() {
    this.element.classList.remove("dragging")
  }
}
