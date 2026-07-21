import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog"]

  connect() {
    if (this.element !== document.body) return

    this.beforeRenderHandler = (event) => {
      event.detail.newBody
        .querySelectorAll("dialog[open]")
        .forEach((d) => d.removeAttribute("open"))
    }
    document.addEventListener("turbo:before-render", this.beforeRenderHandler)
  }

  disconnect() {
    if (this.beforeRenderHandler) {
      document.removeEventListener("turbo:before-render", this.beforeRenderHandler)
    }
  }

  open() {
    if (!this.dialog.open) this.dialog.showModal()
  }

  close() {
    if (this.dialog.open) this.dialog.close()
  }

  backdropHide(event) {
    if ("closedBy" in HTMLDialogElement.prototype) return
    if (event.target === this.dialog) this.close()
  }

  submitSuccess(ev) {
    if (ev.detail.success) this.close()
  }

  get dialog() {
    return this.hasDialogTarget ? this.dialogTarget : this.element
  }
}
