import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog"]

  connect() {
    this.beforeRenderHandler = (event) => {
      event.detail.newBody
        .querySelectorAll("dialog[open]")
        .forEach((d) => d.removeAttribute("open"))
    }
    document.addEventListener("turbo:before-render", this.beforeRenderHandler)

    if (!("commandForElement" in HTMLButtonElement.prototype)) {
      this.invokerHandler = (event) => {
        const button = event.target.closest("[commandfor]")
        if (!button) return
        if (!this.dialog.id || this.dialog.id !== button.getAttribute("commandfor")) return
        const command = button.getAttribute("command")
        if (command == "show-modal") this.open()
        else if (command == "close") this.close()
      }
      document.addEventListener("click", this.invokerHandler)
    }
  }

  disconnect() {
    document.removeEventListener("turbo:before-render", this.beforeRenderHandler)
    if (this.invokerHandler) {
      document.removeEventListener("click", this.invokerHandler)
    }
  }

  open() {
    if (!this.dialog.open) this.dialog.showModal()
  }

  close() {
    if (this.dialog.open) this.dialog.close()
  }

  hide() {
    this.close()
  }

  backdropHide(event) {
    if (event.target === this.dialog) this.close()
  }

  submitSuccess(ev) {
    if (ev.detail.success) this.close()
  }

  openOnFrame(event) {
    if (!this.#isOwnedFrame(event.target)) return
    this.open()
  }

  clearFrame() {
    this.dialog.querySelectorAll("turbo-frame").forEach((frame) => {
      frame.removeAttribute("src")
      frame.innerHTML = ""
    })
  }

  get dialog() {
    return this.hasDialogTarget ? this.dialogTarget : this.element
  }

  #isOwnedFrame(target) {
    return target instanceof Element && target.tagName == "TURBO-FRAME" && this.dialog.contains(target)
  }
}
