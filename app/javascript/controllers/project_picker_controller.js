import { Controller } from "@hotwired/stimulus"

const SEARCH_DEBOUNCE_MS = 180

export default class extends Controller {
  static targets = ["search", "suggestions", "hiddenId", "triggerText", "triggerIcon", "clearButton"]
  static values = {
    suggestionsUrl: String,
    suggestionsFrameId: String,
    selectedBucketId: String,
    selectedName: String,
    selectedIcon: String
  }

  connect() {
    this._searchDebounce = null
  }

  disconnect() {
    this._cancelPendingSearch()
  }

  reset() {
    this.searchTarget.value = ""
    this._loadSuggestions("")
    requestAnimationFrame(() => this.searchTarget.focus())
  }

  cancel() {
    this.searchTarget.value = ""
    this.suggestionsTarget.removeAttribute("src")
    this.suggestionsTarget.replaceChildren()
    this._cancelPendingSearch()
    this.element.querySelector("dialog").close()
  }

  clear() {
    this.selectedBucketIdValue = ""
    this.selectedNameValue = ""
    this.selectedIconValue = ""
    this._applySelectionAndClose()
  }

  search() {
    const q = this.searchTarget.value.trim()
    this._cancelPendingSearch()
    this._searchDebounce = setTimeout(() => this._loadSuggestions(q), SEARCH_DEBOUNCE_MS)
  }

  choose(event) {
    const { bucketId, projectName, projectIcon } = event.currentTarget.dataset

    this.selectedBucketIdValue = bucketId || ""
    this.selectedNameValue = projectName || ""
    this.selectedIconValue = projectIcon || ""
    this._applySelectionAndClose()
  }

  _loadSuggestions(q) {
    const url = new URL(this.suggestionsUrlValue, window.location.origin)
    if (q) url.searchParams.set("q", q)
    url.searchParams.set("frame_id", this.suggestionsFrameIdValue)
    this.suggestionsTarget.src = url.toString()
  }

  _applySelectionAndClose() {
    this.hiddenIdTarget.value = this.selectedBucketIdValue
    this.triggerTextTarget.textContent = this.selectedNameValue || "Project"
    this.triggerIconTarget.style.setProperty("--icon-mask", this._iconMask())
    this.clearButtonTarget.disabled = !this.selectedBucketIdValue
    this.searchTarget.value = ""
    this.suggestionsTarget.removeAttribute("src")
    this.suggestionsTarget.replaceChildren()
    this._cancelPendingSearch()
    this.element.querySelector("dialog").close()
  }

  _iconMask() {
    const icon = this.selectedIconValue || "tag"

    return `var(--icon-${icon})`
  }

  _cancelPendingSearch() {
    if (this._searchDebounce) clearTimeout(this._searchDebounce)
    this._searchDebounce = null
  }
}
