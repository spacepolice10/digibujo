import { Controller } from "@hotwired/stimulus"

// The browser keeps the composer above the keyboard by resizing the viewport.
// This controller only reflects composer focus in the surrounding mobile UI.
export default class extends Controller {
  connect() {
    this.tabbar = document.querySelector(".tabbar--navigation")
    this.editor = this.element.querySelector('[data-composer-editor-target~="editor"]')
    this.events = new AbortController()
    const { signal } = this.events

    this.element.addEventListener("focusin", (event) => {
      if (this.editor?.contains(event.target)) this.#open()
    }, { signal })
    this.element.addEventListener("focusout", () => this.#scheduleClose(), { signal })

    if (this.editor?.contains(document.activeElement)) this.#open()
  }

  disconnect() {
    this.events?.abort()
    if (this.closeFrame != null) cancelAnimationFrame(this.closeFrame)
    this.#close()
  }

  #open() {
    if (this.closeFrame != null) cancelAnimationFrame(this.closeFrame)
    this.closeFrame = null
    document.documentElement.classList.add("keyboard-open")
    this.#hideTabbar(true)
  }

  #scheduleClose() {
    if (this.closeFrame != null) cancelAnimationFrame(this.closeFrame)
    this.closeFrame = requestAnimationFrame(() => {
      this.closeFrame = null
      if (!this.editor?.contains(document.activeElement)) this.#close()
    })
  }

  #close() {
    document.documentElement.classList.remove("keyboard-open")
    this.#hideTabbar(false)
  }

  #hideTabbar(hidden) {
    this.tabbar?.toggleAttribute("inert", hidden)
    if (hidden) this.tabbar?.setAttribute("aria-hidden", "true")
    else this.tabbar?.removeAttribute("aria-hidden")
  }
}
