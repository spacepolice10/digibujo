import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.onKeydown = this.onKeydown.bind(this)
    this.onKeyup = this.onKeyup.bind(this)
    this.onFocusin = this.onFocusin.bind(this)
    this.onBlur = this.hide.bind(this)
    this.onVisibilityChange = this.onVisibilityChange.bind(this)
    this.beforeVisit = this.hide.bind(this)

    document.addEventListener("keydown", this.onKeydown)
    document.addEventListener("keyup", this.onKeyup)
    document.addEventListener("focusin", this.onFocusin)
    window.addEventListener("blur", this.onBlur)
    document.addEventListener("visibilitychange", this.onVisibilityChange)
    document.addEventListener("turbo:before-visit", this.beforeVisit)
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKeydown)
    document.removeEventListener("keyup", this.onKeyup)
    document.removeEventListener("focusin", this.onFocusin)
    window.removeEventListener("blur", this.onBlur)
    document.removeEventListener("visibilitychange", this.onVisibilityChange)
    document.removeEventListener("turbo:before-visit", this.beforeVisit)
    this.hide()
  }

  onKeydown(event) {
    if (this.#shouldIgnore(event)) {
      this.hide()
      return
    }

    if (event.shiftKey) this.show()
  }

  onKeyup(event) {
    if (!event.shiftKey) this.hide()
  }

  onFocusin(event) {
    if (this.#shouldIgnore(event)) this.hide()
  }

  onVisibilityChange() {
    if (document.hidden) this.hide()
  }

  show() {
    this.element.classList.add("show-hotkey-hint")
  }

  hide() {
    this.element.classList.remove("show-hotkey-hint")
  }

  #shouldIgnore(event) {
    return event.defaultPrevented ||
      event.target.closest("input, textarea, [contenteditable], lexxy-editor, .lexxy-editor__content")
  }
}
