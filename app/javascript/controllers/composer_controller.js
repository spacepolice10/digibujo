import { Controller } from "@hotwired/stimulus"

function swapWithViewTransition(update) {
  if (document.startViewTransition && !matchMedia("(prefers-reduced-motion: reduce)").matches) {
    return document.startViewTransition(update)
  }
  update()
}


export default class extends Controller {
  connect() {
    this.previousContent = null

    this.handleRender = this.#handleRender.bind(this)
    this.handleSubmit = this.#handleSubmit.bind(this)
    this.onKeydown = this.#onKeydown.bind(this)
    this.onInlineEnter = this.#onInlineEnter.bind(this)


    window.addEventListener("beforeunload", (event) => {
      if (this.#preventDismissIfContentExists()) {
        event.preventDefault();
        event.returnValue = "";
        return "";
      }
    });

    this.element.addEventListener("turbo:before-frame-render", this.handleRender)
    this.element.addEventListener("turbo:submit-end", this.handleSubmit, true)
    this.element.addEventListener("keydown", this.onInlineEnter, true)
    document.addEventListener("keydown", this.onKeydown)
  }

  disconnect() {
    this.element.removeEventListener("turbo:before-frame-render", this.handleRender)
    this.element.removeEventListener("turbo:submit-end", this.handleSubmit, true)
    this.element.removeEventListener("keydown", this.onInlineEnter, true)
    document.removeEventListener("keydown", this.onKeydown)
  }

  submit(event) {
    if (event?.isComposing) return

    const form = this.#form
    if (!form) return

    const editor = form.querySelector("lexxy-editor")
    if (editor.hasOpenPrompt) return

    event?.preventDefault()
    form.requestSubmit()
  }

  submitWithMakeAnother(event) {
    if (event?.isComposing) return

    const form = this.#form
    if (!form) return

    event?.preventDefault()
    form.requestSubmit(form.querySelector('button[name="another"]'))
  }

  cancel(event) {
    event?.preventDefault()
    if (this.#preventDismissIfContentExists()) return

    this.restore()
  }

  dismiss() {
    if (this.#preventDismissIfContentExists()) return

    this.restore()
  }

  restore() {
    if (this.previousContent == null) return

    swapWithViewTransition(() => {
      this.element.removeAttribute("src")
      this.element.innerHTML = this.previousContent
      this.previousContent = null
      this.#rebind()
      this.element.querySelector("a, button")?.focus()
    })
  }

  #handleRender(event) {
    if (event.target != this.element) return

    const enteringForm = event.detail.newFrame?.querySelector("[data-composer-form]")
    const onTrigger = !this.#form

    if (!enteringForm || !onTrigger) return

    this.previousContent = this.element.innerHTML

    event.detail.render = (currentFrame, newFrame) => {
      const transition = swapWithViewTransition(() => {
        currentFrame.innerHTML = newFrame.innerHTML
      })

      const focus = () => currentFrame.querySelector("lexxy-editor")?.focus()

      if (transition) transition.finished.then(focus)
      else focus()
    }
  }

  #handleSubmit(event) {
    const form = event.target
    if (!form?.hasAttribute("data-composer-form")) return
    if (!this.element.contains(form)) return
    if (!event.detail.success) return

    const submitter = event.detail.formSubmission?.submitter
    if (submitter?.name == "another") {
      this.#clientSideRestore()
      return
    }

    this.restore()
  }

  #preventDismissIfContentExists() {
    const form = this.#form
    if (!form) return false

    const editor = form.querySelector("lexxy-editor")

    if ((editor?.toString().trim().length ?? 0) > 0) {
      const confirmed = confirm("Are you sure you want to dismiss the composer? Any unsaved content will be lost.")
      if (!confirmed) return true
    }

    return false
  }

  #clientSideRestore() {
    const form = this.#form
    if (!form) return

    const editor = form.querySelector("lexxy-editor")
    if (editor) editor.value = ""

    editor?.focus()
    this.#rebind()
  }

  #onKeydown(event) {
    if (event.key != "Escape") return
    if (this.#preventDismissIfContentExists()) return

    event.preventDefault()
    this.restore()
  }

  #onInlineEnter(event) {
    if (event.key != "Enter") return
    if (event.defaultPrevented || event.isComposing) return
    if (event.metaKey || event.ctrlKey || event.altKey) return

    const form = this.#form
    if (!form) return

    const editor = form.querySelector('lexxy-editor[preset="inline"]')
    if (!editor?.contains(event.target)) return

    event.preventDefault()
    event.stopPropagation()

    if (event.shiftKey) this.submitWithMakeAnother(event)
    else this.submit(event)
  }

  #rebind() {
    this.element.dispatchEvent(new CustomEvent("composer:rebind"))
  }

  get #form() {
    return this.element.querySelector("[data-composer-form]")
  }
}
