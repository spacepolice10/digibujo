import { Controller } from "@hotwired/stimulus"

// CSS owns focus-driven geometry. This controller only keeps the visually
// hidden mobile tabbar out of the accessibility and keyboard navigation trees.
export default class extends Controller {
  connect() {
    this.mobile = document.body.dataset.platform === "mobile"
    if (!this.mobile) return

    this.tabbar = document.querySelector(".tabbar--navigation")
    this.editor = this.element.querySelector('[data-composer-editor-target~="editor"]')
    this.events = new AbortController()
    const { signal } = this.events

    this.element.addEventListener("focusin", (event) => {
      if (event.target === this.#editorContent) this.#open()
    }, { signal })
    this.element.addEventListener("focusout", () => this.#scheduleClose(), { signal })

    if (document.activeElement === this.#editorContent) this.#open()
  }

  disconnect() {
    if (!this.mobile) return

    this.events?.abort()
    if (this.closeFrame != null) cancelAnimationFrame(this.closeFrame)
    this.#close()
  }

  #open() {
    if (this.closeFrame != null) cancelAnimationFrame(this.closeFrame)
    this.closeFrame = null
    this.#hideTabbar(true)
  }

  #scheduleClose() {
    if (this.closeFrame != null) cancelAnimationFrame(this.closeFrame)
    this.closeFrame = requestAnimationFrame(() => {
      this.closeFrame = null
      if (document.activeElement !== this.#editorContent) this.#close()
    })
  }

  #close() {
    this.#hideTabbar(false)
  }

  #hideTabbar(hidden) {
    this.tabbar?.toggleAttribute("inert", hidden)
    if (hidden) this.tabbar?.setAttribute("aria-hidden", "true")
    else this.tabbar?.removeAttribute("aria-hidden")
  }

  get #editorContent() {
    return this.editor?.editorContentElement ??
      this.editor?.querySelector(".lexxy-editor__content")
  }
}
