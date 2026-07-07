import { Controller } from "@hotwired/stimulus"
import { swapWithViewTransition } from "helpers/view_transition"

export default class extends Controller {
  connect() {
    this.element.dataset.composerPreviousContent = this.element.innerHTML
    this.element.addEventListener("composer:restore", this.restore)
  }

  beforeFrameRender(event) {
    if (event.target != this.element) return

    const enteringForm = event.detail.newFrame?.querySelector("[data-composer-form]")
    if (!enteringForm || this.element.querySelector("[data-composer-form]")) return

    this.element.dataset.composerPreviousContent = this.element.innerHTML

    event.detail.render = (currentFrame, newFrame) => {
      const transition = swapWithViewTransition(() => {
        currentFrame.innerHTML = newFrame.innerHTML
      })

      const focus = () => currentFrame.querySelector("lexxy-editor")?.focus()

      if (transition) transition.finished.then(focus)
      else focus()
    }
  }

  restore = () => {
    const previousContent = this.element.dataset.composerPreviousContent
    if (previousContent == null) return

    swapWithViewTransition(() => {
      this.element.removeAttribute("src")
      this.element.innerHTML = previousContent
      this.element.dispatchEvent(new CustomEvent("composer:rebind"))
      this.element.querySelector("a, button")?.focus()
    })
  }
}
