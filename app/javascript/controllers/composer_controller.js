import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["rail"]

  connect() {
    this.boundSyncKeyboardInset = () => this.#syncKeyboardInset()
    this.boundKeydown = (event) => this.#onDocumentKeydown(event)

    this.#visualViewport?.addEventListener("resize", this.boundSyncKeyboardInset)
    this.#visualViewport?.addEventListener("scroll", this.boundSyncKeyboardInset)
    document.addEventListener("keydown", this.boundKeydown, true)

    this.#syncKeyboardInset()
  }

  disconnect() {
    this.#visualViewport?.removeEventListener("resize", this.boundSyncKeyboardInset)
    this.#visualViewport?.removeEventListener("scroll", this.boundSyncKeyboardInset)
    document.removeEventListener("keydown", this.boundKeydown, true)

    if (this.hasRailTarget) this.railTarget.style.removeProperty("bottom")
  }

  submitFinish(event) {
    if (!event.detail.success) return
    if (this.#pageComposer) return

    const target = this.element.closest("turbo-frame") || this.element
    target.dispatchEvent(new CustomEvent("composer:restore", { bubbles: true }))
  }

  escape(event) {
    if (!this.form) return
    if (!this.#eventInForm(event)) return

    event.preventDefault()
    event.stopPropagation()
    this.cancel()
  }

  cancel() {
    const back = this.element.querySelector(".bullets-form--type-dismiss[href]")
    if (back) {
      back.click()
      return
    }

    if (window.history.length > 1) {
      window.history.back()
    }
  }

  #onDocumentKeydown(event) {
    if (event.key !== "Enter" || event.isComposing) return
    if (!(event.metaKey || event.ctrlKey)) return
    if (!this.#eventInForm(event)) return

    const form = this.form
    if (!form) return

    const editor = form.querySelector("lexxy-editor")
    if (editor?.hasOpenPrompt) return

    event.preventDefault()
    event.stopPropagation()

    const submitter = form.querySelector('button[type="submit"], input[type="submit"]')
    if (submitter) {
      submitter.click()
    } else {
      form.requestSubmit()
    }
  }

  #syncKeyboardInset() {
    if (!this.hasRailTarget) return

    const viewport = this.#visualViewport
    if (!viewport) {
      this.railTarget.style.bottom = "0px"
      return
    }

    // Layout viewport bottom under the keyboard (iOS overlays; Chromium often
    // resizes content so this stays ~0 and sticky bottom:0 is already correct).
    const inset = Math.max(0, Math.round(window.innerHeight - viewport.height - viewport.offsetTop))
    this.railTarget.style.bottom = `${inset}px`
  }

  #eventInForm(event) {
    const form = this.form
    if (!form) return false

    const path = typeof event.composedPath === "function" ? event.composedPath() : []
    if (path.includes(form)) return true

    const target = event.target
    return target instanceof Node && form.contains(target)
  }

  get #pageComposer() {
    return this.element.querySelector(".bullets-form--type-dismiss[href]") != null
      || !this.element.closest("turbo-frame[id]")
  }

  get #visualViewport() {
    return window.visualViewport
  }

  get form() {
    if (this.element.matches("[data-composer-form]")) return this.element
    return this.element.querySelector("[data-composer-form]")
  }
}
