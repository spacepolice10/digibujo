import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.addEventListener("composer:restore", this.close)
  }

  beforeFrameRender(event) {
    if (event.target != this.composerFrame) return
    if (this.element.open) return
    this.element.showModal()
  }

  frameLoad(event) {
    if (event.target != this.composerFrame) return
    const field = event.target.querySelector("lexxy-editor, .bullet-composer--plain-input, input[type='text'], textarea")
    field?.focus()
  }

  close = () => {
    if (this.element.open) this.element.close()
  }

  cancel() {
    this.close()
  }

  closed() {
    const frame = this.composerFrame
    if (!frame) return
    frame.removeAttribute("src")
    frame.innerHTML = ""
    frame.dispatchEvent(new CustomEvent("composer:rebind"))
  }

  backdropClose(event) {
    if (event.target == this.element) this.close()
  }

  get composerFrame() {
    return this.element.querySelector(".dialog--body turbo-frame")
  }
}
