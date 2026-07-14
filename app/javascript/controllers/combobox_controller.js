import { Controller } from "@hotwired/stimulus"
import { get } from "@rails/request.js"
import { debounce } from "helpers/debounce"
import { navigateCombobox } from "helpers/combobox"

const DEFAULT_DEBOUNCE_MS = 80
const MOBILE_DEACTIVATE_MS = 200

export default class extends Controller {
  static targets = ["searchForm", "searchField", "item", "palette"]

  static values = {
    path: String,
    debounceMs: { type: Number, default: DEFAULT_DEBOUNCE_MS },
  }

  #abort = null
  #debouncedSearch = null
  #deactivateTimer = null

  connect() {
    this.mobileSearch =
      this.element.closest(".menu--page-mobile")?.querySelector(".menu--search") ===
      this.element

    this.#debouncedSearch = debounce(
      (input) => this.#performSearch(input),
      this.debounceMsValue,
    )
  }

  disconnect() {
    this.#cancelDeactivate()
    this.#cancelPendingSearch()
  }

  activate() {
    if (!this.mobileSearch) return

    this.#cancelDeactivate()
    this.element.classList.add("menu--search-active")
    
  }

  deactivate() {
    if (!this.mobileSearch) return

    this.#cancelDeactivate()
    this.#deactivateTimer = window.setTimeout(() => {
      this.element.classList.remove("menu--search-active")
      this.#deactivateTimer = null
    }, MOBILE_DEACTIVATE_MS)
  }

  keepFocus(event) {
    if (!this.mobileSearch) return

    event.preventDefault()
  }

  dismiss(event) {
    if (!this.mobileSearch) return

    event.preventDefault()
    this.#cancelDeactivate()
    this.element.classList.remove("menu--search-active")

    if (!this.hasSearchFieldTarget) return

    this.searchFieldTarget.value = ""
    this.#cancelPendingSearch()

    if (this.hasPathValue) {
      this.#abort = new AbortController()
      this.#performSearch(this.searchFieldTarget)
    }

    this.searchFieldTarget.blur()
  }

  search() {
    if (!this.hasPathValue) return
    if (!this.hasSearchFieldTarget) return
    this.#cancelPendingSearch()
    this.#abort = new AbortController()
    this.#debouncedSearch(this.searchFieldTarget)
  }

  navigate(event) {
    if (event.key == "ArrowDown") {
      event.preventDefault()
      this._move("down")
    } else if (event.key == "ArrowUp") {
      event.preventDefault()
      this._move("up")
    } else if (event.key == "Enter" || event.key == " ") {
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
    this.currentPosition = -1
    this._updateItems()
  }

  itemTargetDisconnected() {
    this.currentPosition = -1
    this._updateItems()
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
    this.itemTargets[this.currentPosition].scrollIntoView({ behavior: "smooth", block: "center" })
    this._updateItems()
  }

  _updateItems() {
    this.itemTargets.forEach((item, index) => {
      item.classList.toggle("is-active", index == this.currentPosition)
      item.setAttribute("aria-selected", index == this.currentPosition)
    })
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

  #cancelDeactivate() {
    if (this.#deactivateTimer == null) return

    window.clearTimeout(this.#deactivateTimer)
    this.#deactivateTimer = null
  }
}
