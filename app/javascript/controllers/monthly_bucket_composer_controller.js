import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog"]

  beforeFrameLoad(event) {
    if (event.target.id != "bullet_composer") return
    if (this.dialogTarget.open) return
    this.dialogTarget.showModal()
  }

  frameLoad(event) {
    if (event.target.id != "bullet_composer") return
    event.target.querySelector("lexxy-editor")?.focus()
  }

  close() {
    if (this.dialogTarget.open) this.dialogTarget.close()
  }

  cancel(event) {
    this.close()
  }

  closed() {
    const frame = document.getElementById("bullet_composer")
    if (!frame) return

    frame.removeAttribute("src")
    frame.innerHTML = ""
    frame.dispatchEvent(new CustomEvent("composer:rebind"))
  }

  backdropClose(event) {
    if (event.target == this.dialogTarget) this.close()
  }

  submitEnd(event) {
    if (!event.detail.success) return
    if (!event.target.classList?.contains("bullet-composer")) return

    this.close()
  }
}
