import { Controller } from "@hotwired/stimulus"

const RECENT_STORAGE_KEY = "projects_picker_recent"
const SEARCH_DEBOUNCE_MS = 180

export default class extends Controller {
  static targets = ["search", "suggestions", "hiddenBucketId", "triggerText", "triggerIcon", "clearButton"]
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
    const { id, name, colour, icon, bucketId } = event.currentTarget.dataset
    this.selectedValue = {
      id: this._parseId(id),
      bucketId: this._parseId(bucketId),
      name,
      colour: colour || null,
      icon: icon || null
    }
    this._applySelectionAndClose()
  }

  async createProject(event) {
    const name = event.currentTarget.dataset.name
    const token = document.querySelector('meta[name="csrf-token"]')?.getAttribute("content")
    const response = await fetch("/projects", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
        ...(token ? { "X-CSRF-Token": token } : {})
      },
      body: JSON.stringify({ project: { name } })
    }).catch(() => null)
    if (!response || !response.ok) return
    const data = await response.json().catch(() => null)
    if (!data?.project) return
    const p = data.project
    this.selectedValue = {
      id: this._parseId(p.id),
      bucketId: this._parseId(p.bucket_id),
      name: p.name,
      colour: p.colour || null,
      icon: p.icon || null
    }
    this._applySelectionAndClose()
  }

  save() {
    this._applySelectionAndClose()
  }

  async submitOnEnter(event) {
    if (event.key != "Enter") return
    if (this.suggestionsTarget.querySelector(".is-active")) return

    const name = this.searchTarget.value.trim()
    if (!name) return

    event.preventDefault()

    const exact = this._suggested.find(item => item.name == name)
    if (exact) {
      this.selectedValue = this._normalizeProject(exact)
      this._applySelectionAndClose()
      return
    }
    const token = document.querySelector('meta[name="csrf-token"]')?.getAttribute("content")
    const response = await fetch("/projects", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
        ...(token ? { "X-CSRF-Token": token } : {})
      },
      body: JSON.stringify({ project: { name } })
    }).catch(() => null)
    if (!response || !response.ok) return
    const data = await response.json().catch(() => null)
    if (!data?.project) return
    const p = data.project
    this.selectedValue = {
      id: this._parseId(p.id),
      bucketId: this._parseId(p.bucket_id),
      name: p.name,
      colour: p.colour || null,
      icon: p.icon || null
    }
    this._applySelectionAndClose()
  }

  disconnect() {
    this._cancelPendingSearch()
  }

  _normalizeProject(project) {
    if (!project || !project.name) return {}
    return {
      id: this._parseId(project.id),
      bucketId: this._parseId(project.bucketId),
      name: project.name,
      colour: project.colour || null,
      icon: project.icon || null
    }
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
      if (!raw) return { item: null, list: [] }
      const parsed = JSON.parse(raw)
      if (!parsed || !parsed.name) return { item: null, list: [] }
      const normalized = this._normalizeProject(parsed)
      return { item: normalized, list: [normalized] }
    } catch {
      return { item: null, list: [] }
    }
  }

  _renderSuggestions() {
    const fragment = document.createDocumentFragment()
    const { item: recentItem, list: recentList } = this._loadRecent()
    const q = this.searchTarget.value.trim()

    if (!q) {
      if (this.selectedValue.name) {
        this._appendSection(fragment, "selected:", [this.selectedValue])
      }
      const recentFiltered = recentList.filter(
        item => item.name != this.selectedValue.name
      )
      this._appendSection(fragment, "recent:", recentFiltered)
    } else {
      this._appendSection(fragment, "suggested:", this._suggested)
      const hasExactMatch =
        this.selectedValue.name == q || this._suggested.some(item => item.name == q)
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
    element.dataset.bucketId = entry.bucketId || entry.bucket_id || ""
    element.dataset.colour = entry.colour || ""
    element.dataset.icon = entry.icon || ""

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
    if (this.hasTriggerIconTarget) {
      const icon = this.projectValue.icon || "tag"
      this.triggerIconTarget.style.setProperty("--icon-mask", `var(--icon-${icon})`)
    }
  }

  _applySelectionAndClose() {
    this.projectValue = { ...this.selectedValue }
    this.hiddenBucketIdTarget.value = this.selectedValue.bucketId ? String(this.selectedValue.bucketId) : ""
    this._saveRecent(this.selectedValue)
    this.searchTarget.value = ""
    this._suggested = []
    this._cancelPendingSearch()
    this._renderSuggestions()
    this._updateText()
    this.element.querySelector("dialog").close()
  }
}
