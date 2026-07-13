import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog"]

  connect() {
    // Strip `open` from dialogs in cached snapshots before Turbo renders them
    this.beforeRenderHandler = (event) => {
      event.detail.newBody
        .querySelectorAll("dialog[open]")
        .forEach((d) => d.removeAttribute("open"))
    }
    document.addEventListener("turbo:before-render", this.beforeRenderHandler)

    // Fallback for browsers without native invoker commands support
    if (!("commandForElement" in HTMLButtonElement.prototype)) {
      this.invokerHandler = (event) => {
        const button = event.target.closest("[commandfor]")
        if (!button) return
        if (!this.dialogTarget.id || this.dialogTarget.id !== button.getAttribute("commandfor")) return
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
    this.dialogTarget.showModal()
  }

  close() {
    this.dialogTarget.close()
  }

  hide() {
    this.close()
  }

  backdropHide(event) {
    if (event.target === this.dialogTarget) {
      this.dialogTarget.close()
    }
  }


  submitSuccess(ev) {
    if (ev.detail.success) {
      this.dialogTarget.close()
    }
  }
}
