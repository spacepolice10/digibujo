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
  }

  disconnect() {
    document.removeEventListener("turbo:before-render", this.beforeRenderHandler)
  }

  open() {
    this.previousUrl = window.location.href
    this.dialogTarget.showModal()
  }

  close() {
    this.#closeAndRestoreUrl()
  }

  // Close when clicking the backdrop (outside the dialog box)
  backdropClose(event) {
    if (event.target === this.dialogTarget) {
      this.#closeAndRestoreUrl()
    }
  }

  // Close after a successful turbo stream submission from within the dialog
  submitEnd(event) {
    if (event.detail.success) {
      this.previousUrl = null
      this.dialogTarget.close()
    }
  }

  #closeAndRestoreUrl() {
    this.dialogTarget.close()
    if (this.previousUrl) {
      history.replaceState(history.state, "", this.previousUrl)
      this.previousUrl = null
    }
  }
}
