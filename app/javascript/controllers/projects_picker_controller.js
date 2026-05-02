import { Controller } from "@hotwired/stimulus"

const RECENT_STORAGE_KEY = "projects_picker_recent"
const SEARCH_DEBOUNCE_MS = 180

export default class extends Controller {
  static targets = ["search", "suggestions", "hiddenId", "hiddenName", "triggerText", "clearButton"]
  static values = {
    project: { type: Object, default: {} },
    selected: { type: Object, default: {} }
  }

  connect() {
    this._suggested = []
    this._searchToken = 0
    this._searchDebounce = null
    this._searchAbortController = null
    this.projectValue = this._normalizeProject(this.projectValue)
    this.reset()
  }

  projectValueChanged() {
    this.selectedValue = this._normalizeProject(this.projectValue)
    this._updateText()
  }

  selectedValueChanged() {
    this.clearButtonTarget.disabled = !this.selectedValue.name
    this._renderSuggestions()
  }

  reset() {
    this.selectedValue = { ...this.projectValue }
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
    const { id, name, colour } = event.currentTarget.dataset
    this.selectedValue = { id: this._parseId(id), name, colour: colour || null }
    this._applySelectionAndClose()
  }

  createProject(event) {
    const name = event.currentTarget.dataset.name
    this.selectedValue = { id: null, name, colour: null }
    this._applySelectionAndClose()
  }

  save() {
    this._applySelectionAndClose()
  }

  submitOnEnter(event) {
    if (event.key != "Enter") return
    if (this.suggestionsTarget.querySelector(".is-active")) return

    const name = this.searchTarget.value.trim()
    if (!name) return

    event.preventDefault()

    const exact = this._suggested.find(item => item.name == name)
    if (exact) {
      this.selectedValue = this._normalizeProject(exact)
    } else {
      this.selectedValue = { id: null, name, colour: null }
    }
    this._applySelectionAndClose()
  }

  disconnect() {
    this._cancelPendingSearch()
  }

  _normalizeProject(project) {
    if (!project || !project.name) return {}
    return { id: this._parseId(project.id), name: project.name, colour: project.colour || null }
  }

  _parseId(value) {
    if (value == null || value == "") return null
    const parsed = parseInt(value, 10)
    return Number.isNaN(parsed) ? null : parsed
  }

  async _loadSuggestions(q) {
    const token = ++this._searchToken
    this._searchAbortController = new AbortController()
    const response = await fetch(`/projects.json?q=${encodeURIComponent(q)}`, {
      signal: this._searchAbortController.signal
    }).catch(() => null)

    if (!response || !response.ok || token != this._searchToken) return
    const data = await response.json().catch(() => ({ projects: [] }))
    if (token != this._searchToken) return
    this._suggested = Array.isArray(data.projects) ? data.projects : []
    this._renderSuggestions()
  }

  _cancelPendingSearch() {
    if (this._searchDebounce) clearTimeout(this._searchDebounce)
    this._searchDebounce = null
    this._searchToken += 1
    if (this._searchAbortController) this._searchAbortController.abort()
    this._searchAbortController = null
  }

  _saveRecent(project) {
    try {
      localStorage.setItem(RECENT_STORAGE_KEY, JSON.stringify(project))
    } catch {
      // Ignore storage failures and keep form behavior intact.
    }
  }

  _loadRecent() {
    try {
      const raw = localStorage.getItem(RECENT_STORAGE_KEY)
      if (!raw) return []
      const parsed = JSON.parse(raw)
      if (!parsed || !parsed.name) return []
      return [this._normalizeProject(parsed)]
    } catch {
      return []
    }
  }

  _renderSuggestions() {
    const fragment = document.createDocumentFragment()
    const selected = this.selectedValue.name ? [this.selectedValue] : []
    const q = this.searchTarget.value.trim()

    if (!q) {
      this._appendSection(fragment, "selected:", selected, true)
      const recent = this._loadRecent().filter(item => item.name != this.selectedValue.name)
      this._appendSection(fragment, "recent:", recent, false)
    } else {
      this._appendSection(fragment, "suggested:", this._suggested)
      const hasExactMatch = this.selectedValue.name == q || this._suggested.some(item => item.name == q)
      if (!hasExactMatch) {
        fragment.appendChild(this._createCreateItem(q))
      }
    }

    this.suggestionsTarget.replaceChildren(fragment)
  }

  _appendSection(fragment, title, items) {
    if (!items || items.length == 0) return

    const sectionName = document.createElement("li")
    sectionName.className = "projects-picker--section-name"
    sectionName.setAttribute("aria-hidden", "true")
    sectionName.textContent = title
    fragment.appendChild(sectionName)

    items.forEach(item => {
      const isChecked = item.name == this.selectedValue.name
      fragment.appendChild(this._createItem(item, isChecked))
    })
  }

  _createItem(entry, checked) {
    const element = document.createElement("li")
    element.className = "projects-picker--suggestion"
    element.setAttribute("role", "option")
    element.dataset.comboboxTarget = "item"
    element.dataset.action = "click->projects-picker#choose"
    element.dataset.name = entry.name
    element.dataset.id = entry.id || ""
    element.dataset.colour = entry.colour || ""

    const checkbox = document.createElement("input")
    checkbox.type = "checkbox"
    checkbox.setAttribute("aria-hidden", "true")
    checkbox.tabIndex = -1
    checkbox.checked = checked

    element.appendChild(checkbox)
    element.append(` ${entry.name}`)
    return element
  }

  _createCreateItem(name) {
    const item = document.createElement("li")
    item.className = "projects-picker--create"
    item.setAttribute("role", "option")
    item.dataset.comboboxTarget = "item"
    item.dataset.action = "click->projects-picker#createProject"
    item.dataset.name = name
    item.textContent = `Create "${name}"`
    return item
  }

  _updateText() {
    this.triggerTextTarget.textContent = this.projectValue.name ? this.projectValue.name : "Project"
  }

  _applySelectionAndClose() {
    this.projectValue = { ...this.selectedValue }
    this.hiddenIdTarget.value = this.selectedValue.id ? String(this.selectedValue.id) : ""
    this.hiddenNameTarget.value = this.selectedValue.name ? this.selectedValue.name : ""
    this._saveRecent(this.selectedValue)
    this.searchTarget.value = ""
    this._suggested = []
    this._cancelPendingSearch()
    this._renderSuggestions()
    this._updateText()
    this.element.querySelector("dialog").close()
  }
}
