import { Controller } from "@hotwired/stimulus"

const SEARCH_DEBOUNCE_MS = 180

export default class extends Controller {
  static targets = ["search", "suggestions", "hiddenId", "triggerText", "clearButton"]
  static values = {
    context: { type: Object, default: {} },
    selected: { type: Object, default: {} },
    excludeId: Number
  }

  connect() {
    this._suggested = []
    this._searchToken = 0
    this._searchDebounce = null
    this._searchAbortController = null
    this.contextValue = this._normalizeContext(this.contextValue)
    this.reset()
  }

  disconnect() {
    this._cancelPendingSearch()
  }

  contextValueChanged() {
    this.selectedValue = this._normalizeContext(this.contextValue)
    this._updateText()
  }

  selectedValueChanged() {
    this.clearButtonTarget.disabled = !this.selectedValue.name
    this._renderSuggestions()
  }

  reset() {
    this.selectedValue = { ...this.contextValue }
    this.searchTarget.value = ""
    this._suggested = []
    this._cancelPendingSearch()
    this._renderSuggestions()
    requestAnimationFrame(() => this.searchTarget.focus())
  }

  clear() {
    this.selectedValue = {}
    this._applySelectionAndClose()
  }

  cancel() {
    this.reset()
    this.element.querySelector("dialog").close()
  }

  save() {
    this._applySelectionAndClose()
  }

  search() {
    const q = this.searchTarget.value.trim()
    this._cancelPendingSearch()
    if (!q) {
      this._suggested = []
      this._renderSuggestions()
      return
    }
    this._searchDebounce = setTimeout(() => this._loadSuggestions(q), SEARCH_DEBOUNCE_MS)
  }

  choose(event) {
    const { id, name, icon } = event.currentTarget.dataset
    this.selectedValue = { id: this._parseId(id), name, icon: icon || "line-dashed" }
    this._applySelectionAndClose()
  }

  submitOnEnter(event) {
    if (event.key != "Enter") return
    if (this.suggestionsTarget.querySelector(".is-active")) return

    const query = this.searchTarget.value.trim()
    if (!query) return

    event.preventDefault()
    const exact = this._suggested.find(item => item.name == query || this._labelFor(item) == query)
    if (!exact) return
    this.selectedValue = this._normalizeContext(exact)
    this._applySelectionAndClose()
  }

  _normalizeContext(context) {
    if (!context || !context.name) return {}
    return { id: this._parseId(context.id), name: context.name, icon: context.icon || "line-dashed" }
  }

  _parseId(value) {
    if (value == null || value == "") return null
    const parsed = parseInt(value, 10)
    return Number.isNaN(parsed) ? null : parsed
  }

  async _loadSuggestions(q) {
    const token = ++this._searchToken
    this._searchAbortController = new AbortController()
    const params = new URLSearchParams({ q })
    if (this.hasExcludeIdValue && this.excludeIdValue) params.set("exclude_id", String(this.excludeIdValue))
    const response = await fetch(`/bullets/contexts.json?${params.toString()}`, {
      signal: this._searchAbortController.signal
    }).catch(() => null)

    if (!response || !response.ok || token != this._searchToken) return
    const data = await response.json().catch(() => ({ bullets: [] }))
    if (token != this._searchToken) return
    this._suggested = Array.isArray(data.bullets) ? data.bullets : []
    this._renderSuggestions()
  }

  _cancelPendingSearch() {
    if (this._searchDebounce) clearTimeout(this._searchDebounce)
    this._searchDebounce = null
    this._searchToken += 1
    if (this._searchAbortController) this._searchAbortController.abort()
    this._searchAbortController = null
  }

  _renderSuggestions() {
    const fragment = document.createDocumentFragment()
    const selected = this.selectedValue.name ? [this.selectedValue] : []
    const q = this.searchTarget.value.trim()

    if (!q) {
      this._appendSection(fragment, "selected:", selected)
    } else {
      this._appendSection(fragment, "suggested:", this._suggested)
    }

    this.suggestionsTarget.replaceChildren(fragment)
  }

  _appendSection(fragment, title, items) {
    if (!items || items.length == 0) return

    const sectionName = document.createElement("li")
    sectionName.className = "context-picker--section-name"
    sectionName.setAttribute("aria-hidden", "true")
    sectionName.textContent = title
    fragment.appendChild(sectionName)

    items.forEach(item => {
      const isChecked = this.selectedValue.id
        ? this._parseId(item.id) == this.selectedValue.id
        : item.name == this.selectedValue.name
      fragment.appendChild(this._createItem(item, isChecked))
    })
  }

  _createItem(entry, checked) {
    const element = document.createElement("li")
    element.className = "context-picker--suggestion"
    element.setAttribute("role", "option")
    element.dataset.comboboxTarget = "item"
    element.dataset.action = "click->context-picker#choose"
    element.dataset.name = entry.name
    element.dataset.id = entry.id || ""
    element.dataset.icon = entry.icon || "line-dashed"

    const checkbox = document.createElement("input")
    checkbox.type = "checkbox"
    checkbox.setAttribute("aria-hidden", "true")
    checkbox.tabIndex = -1
    checkbox.checked = checked

    element.appendChild(checkbox)
    element.append(` ${this._labelFor(entry)}`)
    return element
  }

  _updateText() {
    this.triggerTextTarget.textContent = this.contextValue.name ? this._labelFor(this.contextValue) : "Context"
  }

  _labelFor(entry) {
    const id = this._parseId(entry.id)
    return id ? `#${id} ${entry.name}` : entry.name
  }

  _applySelectionAndClose() {
    this.contextValue = { ...this.selectedValue }
    this.hiddenIdTarget.value = this.selectedValue.id ? String(this.selectedValue.id) : ""
    this.searchTarget.value = ""
    this._suggested = []
    this._cancelPendingSearch()
    this._renderSuggestions()
    this._updateText()
    this.element.querySelector("dialog").close()
  }
}
