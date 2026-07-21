import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  dispatchRestore() {
    const target = this.element.closest("turbo-frame") || this.element
    target.dispatchEvent(new CustomEvent("composer:restore", { bubbles: true }))
  }

  submitFinish(event) {
    if (!event.detail.success) return

    this.dispatchRestore()
  }

  escape(event) {
    if (!this.form) return
    if (this.form.closest("dialog[open]")) return

    event.preventDefault()
    event.stopPropagation()
    this.dispatchRestore()
  }

  submit(event) {
    if (event?.isComposing) return

    const form = this.form
    if (!form) return

    const editor = form.querySelector("lexxy-editor")
    if (editor?.hasOpenPrompt) return

    event?.preventDefault()
    form.requestSubmit()
  }

  cancel() {
    this.dispatchRestore()
  }

  get form() {
    if (this.element.matches("[data-composer-form]")) return this.element
    return this.element.querySelector("[data-composer-form]")
  }
}
