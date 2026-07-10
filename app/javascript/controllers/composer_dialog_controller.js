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
    event.target.querySelector("lexxy-editor")?.focus()
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

  submitEnd(event) {
    if (!event.detail.success) return
    if (!event.target.classList?.contains("bullet-composer")) return
    if (event.detail.formSubmission?.submitter?.name == "another") return
    this.close()
  }

  get composerFrame() {
    return this.element.querySelector(".dialog--body turbo-frame")
  }
}
