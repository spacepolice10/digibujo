import { Controller } from "@hotwired/stimulus"
import { get } from "@rails/request.js"
import { debounce } from "helpers/debounce"
import { navigateCombobox } from "helpers/combobox"

const DEFAULT_DEBOUNCE_MS = 80
// iOS Safari often blurs the field (and would hide the palette) before the
// tap synthesizes click — keep results mounted long enough for the link to receive it.
const COLLAPSE_DELAY_MS = 300

export default class extends Controller {
  static targets = ["searchForm", "searchField", "item"]

  static values = {
    path: String,
    debounceMs: { type: Number, default: DEFAULT_DEBOUNCE_MS },
  }

  #abort = null
  #debouncedSearch = null
  #collapseTimer = null

  connect() {
    this.#debouncedSearch = debounce(
      (input) => this.#performSearch(input),
      this.debounceMsValue,
    )

    if (this.#managesPalette) {
      this._expand = this.expand.bind(this)
      this._collapseSoon = this.collapseSoon.bind(this)
      this.element.addEventListener("focusin", this._expand)
      this.element.addEventListener("focusout", this._collapseSoon)
    }
  }

  disconnect() {
    this.#cancelPendingSearch()
    this.#cancelCollapse()

    if (this._expand) {
      this.element.removeEventListener("focusin", this._expand)
      this.element.removeEventListener("focusout", this._collapseSoon)
    }
  }

  expand() {
    this.#cancelCollapse()
    this.element.classList.add("search--open")
  }

  collapseSoon(event) {
    if (event.relatedTarget && this.element.contains(event.relatedTarget)) return

    this.#cancelCollapse()
    this.#collapseTimer = setTimeout(() => this.#collapse(), COLLAPSE_DELAY_MS)
  }

  // Prevent input blur when interacting with the results list (mousedown path).
  keepFocus(event) {
    event.preventDefault()
  }

  dismiss(event) {
    event.preventDefault()

    if (!this.hasSearchFieldTarget) return

    this.searchFieldTarget.value = ""
    this.#cancelPendingSearch()

    if (this.hasPathValue) {
      this.#abort = new AbortController()
      this.#performSearch(this.searchFieldTarget)
    }

    this.#collapse()
    this.searchFieldTarget.blur()
    event.currentTarget.blur()
  }

  search() {
    if (!this.hasPathValue) return
    if (!this.hasSearchFieldTarget) return
    this.#cancelPendingSearch()
    this.#abort = new AbortController()
    this.#debouncedSearch(this.searchFieldTarget)
  }

  // Native search clear (×) and Enter fire `search`. Collapse when empty.
  commit() {
    if (!this.hasSearchFieldTarget) return
    if (this.searchFieldTarget.value.trim()) return
    this.#collapse()
    this.searchFieldTarget.blur()
  }

  navigate(event) {
    if (event.key == "ArrowDown") {
      event.preventDefault()
      this._move("down")
    } else if (event.key == "ArrowUp") {
      event.preventDefault()
      this._move("up")
    } else if (event.key == "Enter") {
      this._activate(event)
    } else if (event.key == " " && (!this.hasSearchFieldTarget || event.target != this.searchFieldTarget)) {
      this._activate(event)
    } else if (event.key == "Escape") {
      this.currentPosition = -1
      this._updateItems()
      if (!this.hasSearchFieldTarget || !this.hasPathValue) return
      if (!this.searchFieldTarget.value.trim()) return

      this.searchFieldTarget.value = ""
      this.#cancelPendingSearch()
      this.#abort = new AbortController()
      this.#performSearch(this.searchFieldTarget)
      event.stopPropagation()
    }
  }

  itemTargetConnected() {
    this.#selectFirstItem()
  }

  itemTargetDisconnected() {
    this.#selectFirstItem()
  }

  _activate(event) {
    if (this.currentPosition < 0) return

    const item = this.itemTargets[this.currentPosition]
    const activatable = this._activatable(item)
    if (!activatable) return

    event.preventDefault()
    activatable.click()
  }

  _activatable(item) {
    if (!item) return null
    if (item.matches("a, button")) return item
    return item.querySelector("a, button")
  }

  _move(direction) {
    this.currentPosition = navigateCombobox(
      this.currentPosition,
      direction,
      this.itemTargets.length,
    )
    if (this.currentPosition >= 0) {
      this.itemTargets[this.currentPosition].scrollIntoView({ behavior: "instant", block: "start" })
    }
    this._updateItems()
  }

  _updateItems() {
    this.itemTargets.forEach((item, index) => {
      item.setAttribute("aria-selected", index == this.currentPosition)
    })
  }

  get #managesPalette() {
    return this.element.querySelector(".search--palette") != null
  }

  #collapse() {
    this.#cancelCollapse()
    this.element.classList.remove("search--open")
  }

  #cancelCollapse() {
    clearTimeout(this.#collapseTimer)
    this.#collapseTimer = null
  }

  async #performSearch(input) {
    const otherFields = {}
    if (this.hasSearchFormTarget) {
      for (const [key, value] of new FormData(this.searchFormTarget)) {
        if (key == "q" || key == input.name) continue
        otherFields[key] = value
      }
    }

    try {
      await get(this.pathValue, {
        query: { ...otherFields, q: input.value.trim() },
        signal: this.#abort.signal,
        responseKind: "turbo-stream",
      })
    } catch (error) {
      if (error.name != "AbortError") console.error("Search failed:", error)
    }
  }

  #cancelPendingSearch() {
    this.#abort?.abort()
    this.#abort = null
  }

  #selectFirstItem() {
    this.currentPosition = this.itemTargets.length > 0 ? 0 : -1
    this._updateItems()
  }
}
