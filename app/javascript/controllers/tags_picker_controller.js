import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["hidden", "chips", "input"]

  connect() {
    this.tags = new Map()
    const existing = this.hiddenTarget.value
    if (existing) {
      existing.split(",").map(t => t.trim()).filter(Boolean).forEach(entry => {
        const [name, colour] = entry.split(":")
        this.tags.set(name, colour || null)
        this.#appendChip(name, colour || null)
      })
    }
  }

  focusInput() {
    this.inputTarget.focus()
  }

  onSelect(event) {
    const { name, colour } = event.detail
    if (name) this.#addTag(name, colour || null)
    this.inputTarget.value = ""
  }

  removeTag(event) {
    const name = event.currentTarget.dataset.name
    this.tags.delete(name)
    event.currentTarget.closest(".pill").remove()
    this.#syncHidden()
  }

  // -- Private --

  #addTag(name, colour) {
    if (this.tags.has(name)) return
    this.tags.set(name, colour || null)
    this.#appendChip(name, colour)
    this.#syncHidden()
  }

  #appendChip(name, colour) {
    const chip = document.createElement("span")
    chip.className = "pill"
    if (colour) {
      chip.style.color = `var(--model-color-${colour})`
      chip.style.background = `var(--model-color-${colour}-bg)`
    }
    chip.innerHTML = `${name} <button type="button" data-action="click->tags-picker#removeTag" data-name="${name}">&times;</button>`
    this.chipsTarget.appendChild(chip)
  }

  #syncHidden() {
    const parts = []
    for (const [name, colour] of this.tags) {
      parts.push(colour ? `${name}:${colour}` : name)
    }
    this.hiddenTarget.value = parts.join(", ")
  }
}
