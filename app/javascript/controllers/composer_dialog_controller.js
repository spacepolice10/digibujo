import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  openOnFrame(event) {
    if (!(event.target instanceof Element)) return
    if (event.target.tagName != "TURBO-FRAME") return
    if (!this.element.contains(event.target)) return
    if (!this.element.open) this.element.showModal()
  }

  clearFrame() {
    this.element.querySelectorAll("turbo-frame").forEach((frame) => {
      frame.removeAttribute("src")
      frame.innerHTML = ""
    })
  }
}
