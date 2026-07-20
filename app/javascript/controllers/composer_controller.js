import { Controller } from "@hotwired/stimulus"

let dismissHintIdCounter = 0

export default class extends Controller {
  connect() {
    this.abortController = new AbortController()
    this.dismissConfirmActive = false
    this.dismissConfirmElement = null
    this.dismissHint = null
    this.dismissHintId = `dismiss-confirm-${++dismissHintIdCounter}`

    window.addEventListener("beforeunload", this.beforeUnload, { signal: this.abortController.signal })
  }

  disconnect() {
    this.abortController.abort()
    this.abortDismiss()
  }

  beforeUnload = (event) => {
    if (!this.hasUnsavedContent) return

    event.preventDefault()
    event.returnValue = ""
  }

  dispatchRestore() {
    const target = this.element.closest("turbo-frame") || this.element
    target.dispatchEvent(new CustomEvent("composer:restore", { bubbles: true }))
  }

  submitEnd(event) {
    if (!event.detail.success) return

    this.resetForm()
  }

  escape(event) {
    if (!this.form) return
    if (this.form.closest("dialog[open]")) return

    event.preventDefault()
    event.stopPropagation()

    if (this.hasUnsavedContent) {
      this.attemptDismiss(this.form)
      return
    }

    this.dispatchRestore()
    this.keepEditorFocus()
  }

  plainEnter(event) {
    if (event.key != "Enter") return
    if (event.defaultPrevented || event.isComposing) return
    if (event.altKey) return
    if (event.shiftKey) return

    event.preventDefault()
    event.stopPropagation()
    this.submit(event)
  }

  editorInput() {
    if (!this.hasUnsavedContent) this.abortDismiss()
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
    if (this.hasUnsavedContent) {
      this.attemptDismiss(this.form)
      return
    }

    this.dispatchRestore()
  }

  dialogCancel(event) {
    event.preventDefault()
    if (this.hasUnsavedContent) {
      this.attemptDismiss(this.form)
    } else {
      this.dispatchRestore()
      this.keepEditorFocus()
    }
  }

  dismiss() {
    if (this.hasUnsavedContent && !this.isDismissConfirming) return
    this.dispatchRestore()
  }

  attemptDismiss(element) {
    if (this.dismissConfirmActive) {
      this.clearDismiss()
      this.dispatchRestore()
      return false
    }

    this.dismissConfirmActive = true
    this.dismissConfirmElement = element
    this.showDismissHint()
    this.shakeDismissElement()
    return true
  }

  abortDismiss() {
    if (this.dismissConfirmActive) this.clearDismiss()
  }

  get isDismissConfirming() {
    return this.dismissConfirmActive
  }

  showDismissHint() {
    if (this.dismissHint?.isConnected) return

    const toasts = document.getElementById("toasts")
    if (!toasts) return

    this.dismissHint = document.createElement("div")
    this.dismissHint.id = this.dismissHintId
    this.dismissHint.className = "toasts--message toasts--notify bullet-composer--dismiss-hint"
    this.dismissHint.setAttribute("role", "status")
    this.dismissHint.textContent = "Press Esc again to close the editor"
    toasts.appendChild(this.dismissHint)
    this.setDismissAttributes()
  }

  setDismissAttributes() {
    const el = this.dismissConfirmElement
    if (!el) return

    el.setAttribute("aria-describedby", this.dismissHintId)
    el.setAttribute("aria-keyshortcuts", "Escape")
    this.contentField?.setAttribute("aria-describedby", this.dismissHintId)
    el.closest("dialog[open]")?.setAttribute("aria-describedby", this.dismissHintId)
  }

  shakeDismissElement() {
    const el = this.dismissConfirmElement
    if (!el) return
    if (matchMedia("(prefers-reduced-motion: reduce)").matches) return

    el.classList.remove("utilities--shaking")
    void el.offsetWidth
    el.classList.add("utilities--shaking")
    el.addEventListener("animationend", () => {
      el.classList.remove("utilities--shaking")
    }, { once: true })
  }

  clearDismiss() {
    this.dismissConfirmActive = false
    this.clearDismissAttributes()
    this.removeDismissHint()
  }

  clearDismissAttributes() {
    const el = this.dismissConfirmElement
    if (!el) return

    el.removeAttribute("aria-describedby")
    el.removeAttribute("aria-keyshortcuts")
    this.contentField?.removeAttribute("aria-describedby")
    el.closest("dialog")?.removeAttribute("aria-describedby")
    this.dismissConfirmElement = null
  }

  removeDismissHint() {
    this.dismissHint?.remove()
    this.dismissHint = null
  }

  resetForm() {
    const field = this.contentField
    if (field?.tagName == "LEXXY-EDITOR") {
      field.value = ""
    } else if (field) {
      field.value = ""
    }

    this.abortDismiss()
    field?.focus()
    this.rebind()
  }

  keepEditorFocus() {
    this.contentField?.focus({ preventScroll: true })
  }

  rebind() {
    this.element.dispatchEvent(new CustomEvent("composer:rebind"))
  }

  get form() {
    if (this.element.matches("[data-composer-form]")) return this.element
    return this.element.querySelector("[data-composer-form]")
  }

  get contentField() {
    const form = this.form
    if (!form) return null

    return form.querySelector("lexxy-editor") ||
      form.querySelector(".bullet-composer--plain-input") ||
      form.querySelector("input[type='text'], textarea")
  }

  get hasUnsavedContent() {
    const field = this.contentField
    if (!field) return false

    if (field.tagName == "LEXXY-EDITOR") {
      return (field.toString?.().trim().length ?? 0) > 0
    }

    return (field.value?.trim().length ?? 0) > 0
  }
}
