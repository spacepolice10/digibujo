import { Controller } from "@hotwired/stimulus"
import { debounce } from "controllers/actions/debounce"

export default class extends Controller {
  static values = {
    key: String,
    delay: { type: Number, default: 500 }
  }

  initialize() {
    this.doSave = debounce(this.doSave.bind(this), this.delayValue)
  }

  connect() {
    this.restore()
    this.element.addEventListener("submit", () => this.clear(), { once: true })
  }

  save(event) {
    this.doSave(event.target)
  }

  // private

  doSave(field) {
    const key = this.keyFor(field)
    if (!key) return
    let value
    if (field.tagName == "TRIX-EDITOR") {
      const hidden = document.getElementById(field.getAttribute("input"))
      value = hidden ? hidden.value : ""
    } else {
      value = field.value
    }
    localStorage.setItem(key, value)
  }

  restore() {
    this.element.querySelectorAll("input[name], textarea[name]").forEach(field => {
      const key = this.keyFor(field)
      if (!key) return
      const saved = localStorage.getItem(key)
      if (saved !== null && field.value === "") field.value = saved
    })

    this.element.querySelectorAll("trix-editor[input]").forEach(field => {
      const key = this.keyFor(field)
      if (!key) return
      const saved = localStorage.getItem(key)
      if (saved === null) return
      if (field.editor) {
        field.editor.loadHTML(saved)
      } else {
        field.addEventListener("trix-initialize", () => field.editor.loadHTML(saved), { once: true })
      }
    })
  }

  clear() {
    const prefix = `persist:${this.keyValue}:`
    Object.keys(localStorage)
      .filter(k => k.startsWith(prefix))
      .forEach(k => localStorage.removeItem(k))
  }

  keyFor(field) {
    const name = field.name || field.getAttribute("input")
    if (!name) return null
    return `persist:${this.keyValue}:${name}`
  }
}
