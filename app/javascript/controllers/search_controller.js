import { Controller } from "@hotwired/stimulus"
import { debounce } from "helpers/debounce"

const DEFAULT_DEBOUNCE_MS = 80

export default class extends Controller {
  static targets = ["input", "section"]
  static values = {
    path: String,
    debounceMs: { type: Number, default: DEFAULT_DEBOUNCE_MS },
  }

  #debouncedReplace = null

  connect() {
    this.#debouncedReplace = debounce(() => this.#replaceSection(), this.debounceMsValue)
  }

  input() {
    this.#debouncedReplace()
  }

  cleanup() {
    this.inputTarget.value = ""
    this.inputTarget.dispatchEvent(new Event("input", { bubbles: true }))
    this.inputTarget.focus()
    this.#replaceSection()
  }

  #replaceSection() {
    if (!this.hasSectionTarget) return

    const q = this.inputTarget.value.trim()
    const url = new URL(this.pathValue || "/search", window.location.origin)
    if (q) {
      url.searchParams.set("q", q)
    } else {
      url.searchParams.delete("q")
    }

    this.sectionTarget.src = `${url.pathname}${url.search}`
  }
}
