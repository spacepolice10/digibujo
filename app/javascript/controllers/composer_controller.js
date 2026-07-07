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

    if (event.detail.formSubmission?.submitter?.name == "another") {
      this.resetForm()
      return
    }

    this.dispatchRestore()
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

  inlineEnter(event) {
    if (event.key != "Enter") return
    if (event.defaultPrevented || event.isComposing) return

    const form = this.form
    if (!form) return

    const editor = form.querySelector("lexxy-editor")
    if (!editor?.contains(event.target)) return

    const chordSubmit = event.metaKey || event.ctrlKey

    if (chordSubmit) {
      if (event.altKey) return
    } else {
      if (event.metaKey || event.ctrlKey || event.altKey) return
      if (editor.getAttribute("preset") != "inline") return
    }

    event.preventDefault()
    event.stopPropagation()

    if (event.shiftKey) this.submitWithMakeAnother(event)
    else this.submit(event)
  }

  editorInput() {
    if (!this.hasUnsavedContent) this.abortDismiss()
  }

  submit(event) {
    if (event?.isComposing) return

    const form = this.form
    if (!form) return

    const editor = form.querySelector("lexxy-editor")
    if (editor.hasOpenPrompt) return

    event?.preventDefault()
    form.requestSubmit()
  }

  submitWithMakeAnother(event) {
    if (event?.isComposing) return

    const form = this.form
    if (!form) return

    event?.preventDefault()
    form.requestSubmit(form.querySelector('button[name="another"]'))
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
    el.querySelector("lexxy-editor")?.setAttribute("aria-describedby", this.dismissHintId)
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
    el.querySelector("lexxy-editor")?.removeAttribute("aria-describedby")
    el.closest("dialog")?.removeAttribute("aria-describedby")
    this.dismissConfirmElement = null
  }

  removeDismissHint() {
    this.dismissHint?.remove()
    this.dismissHint = null
  }

  resetForm() {
    const editor = this.form?.querySelector("lexxy-editor")
    if (editor) editor.value = ""

    this.abortDismiss()
    editor?.focus()
    this.rebind()
  }

  keepEditorFocus() {
    this.form?.querySelector("lexxy-editor")?.focus({ preventScroll: true })
  }

  rebind() {
    this.element.dispatchEvent(new CustomEvent("composer:rebind"))
  }

  get form() {
    if (this.element.matches("[data-composer-form]")) return this.element
    return this.element.querySelector("[data-composer-form]")
  }

  get hasUnsavedContent() {
    const editor = this.form?.querySelector("lexxy-editor")
    return (editor?.toString().trim().length ?? 0) > 0
  }
}
