import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    const input = this.element.querySelector("input[type=date]")
    if (input && !input.min) {
      input.min = new Date().toISOString().split("T")[0]
    }
  }
}
