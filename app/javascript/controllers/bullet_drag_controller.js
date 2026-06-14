import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { id: String }

  dragstart(event) {
    event.dataTransfer.effectAllowed = "move"
    event.dataTransfer.setData("bullet-id", this.idValue)

    const zone = this.element.closest("[data-monthly-bucket-drop-pops-on-value]")
    const sourcePopsOn = zone?.dataset.monthlyBucketDropPopsOnValue ?? ""
    event.dataTransfer.setData("source-pops-on", sourcePopsOn)

    this.element.classList.add("dragging")
  }

  dragend() {
    this.element.classList.remove("dragging")
  }
}
