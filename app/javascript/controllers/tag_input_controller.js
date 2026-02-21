import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["hidden", "chips", "input", "suggestions"]

  connect() {
    this.tags = new Set()
    const existing = this.hiddenTarget.value
    if (existing) {
      existing.split(",").map(t => t.trim()).filter(Boolean).forEach(name => {
        this.tags.add(name)
        this.#appendChip(name)
      })
    }
  }

  onInput() {
    clearTimeout(this._debounce)
    this._debounce = setTimeout(() => {
      const query = this.inputTarget.value.trim()
      const frame = this.suggestionsTarget
      if (query.length > 0) {
        frame.src = `/tags?q=${encodeURIComponent(query)}`
      } else {
        frame.innerHTML = ""
        frame.removeAttribute("src")
      }
    }, 200)
  }

  onKeydown(event) {
    if (event.key === "Enter" || event.key === ",") {
      event.preventDefault()
      const name = this.inputTarget.value.replace(/,/g, "").trim().toLowerCase()
      if (name) this.#addTag(name)
    }
  }

  select(event) {
    const name = event.currentTarget.dataset.name
    if (name) this.#addTag(name)
  }

  removeTag(event) {
    const name = event.currentTarget.dataset.name
    this.tags.delete(name)
    event.currentTarget.closest(".tag-chip").remove()
    this.#syncHidden()
  }

  #addTag(name) {
    if (this.tags.has(name)) {
      this.inputTarget.value = ""
      return
    }
    this.tags.add(name)
    this.#appendChip(name)
    this.#syncHidden()
    this.inputTarget.value = ""
    this.suggestionsTarget.innerHTML = ""
    this.suggestionsTarget.removeAttribute("src")
  }

  #appendChip(name) {
    const chip = document.createElement("span")
    chip.className = "tag-chip"
    chip.innerHTML = `${name} <button type="button" data-action="click->tag-input#removeTag" data-name="${name}">&times;</button>`
    this.chipsTarget.appendChild(chip)
  }

  #syncHidden() {
    this.hiddenTarget.value = Array.from(this.tags).join(", ")
  }
}
