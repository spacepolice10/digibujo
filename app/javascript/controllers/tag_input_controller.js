import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["hidden", "chips", "input", "suggestions"]

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
    this.activeIndex = -1

    // Show popover when turbo frame loads content
    this.suggestionsTarget.addEventListener("turbo:frame-load", () => {
      this.activeIndex = -1
      if (this.#options.length > 0) {
        this.suggestionsTarget.showPopover()
      } else {
        this.suggestionsTarget.hidePopover()
      }
    })
  }

  focusInput() {
    this.inputTarget.focus()
  }

  onInput() {
    clearTimeout(this._debounce)
    this._debounce = setTimeout(() => {
      const query = this.inputTarget.value.trim()
      const frame = this.suggestionsTarget
      if (query.length > 0) {
        frame.src = `/tags?q=${encodeURIComponent(query)}`
      } else {
        this.#closeSuggestions()
      }
    }, 200)
  }

  onKeydown(event) {
    const options = this.#options
    const open = options.length > 0 && this.suggestionsTarget.matches(":popover-open")

    if (event.key == "ArrowDown") {
      if (!open) return
      event.preventDefault()
      this.activeIndex = Math.min(this.activeIndex + 1, options.length - 1)
      this.#highlightOption()
      return
    }

    if (event.key == "ArrowUp") {
      if (!open) return
      event.preventDefault()
      this.activeIndex = Math.max(this.activeIndex - 1, -1)
      this.#highlightOption()
      return
    }

    if (event.key == "Escape") {
      if (open) {
        event.preventDefault()
        event.stopPropagation()
        this.#closeSuggestions()
      }
      return
    }

    if (event.key == "Enter" || event.key == ",") {
      event.preventDefault()
      if (open && this.activeIndex >= 0 && this.activeIndex < options.length) {
        this.#selectOption(options[this.activeIndex])
      } else {
        const name = this.inputTarget.value.replace(/,/g, "").trim().toLowerCase()
        if (name) this.#addTag(name, null)
      }
    }
  }

  onBlur() {
    // Delay so click events on suggestions can fire first
    setTimeout(() => this.#closeSuggestions(), 150)
  }

  select(event) {
    event.preventDefault()
    const name = event.currentTarget.dataset.name
    if (name) this.#addTag(name, null)
    this.inputTarget.focus()
  }

  selectColour(event) {
    event.preventDefault()
    event.stopPropagation()
    const colour = event.currentTarget.dataset.colour
    const name = event.currentTarget.dataset.name
    if (name) this.#addTag(name, colour)
    this.inputTarget.focus()
  }

  removeTag(event) {
    const name = event.currentTarget.dataset.name
    this.tags.delete(name)
    event.currentTarget.closest(".tag-chip").remove()
    this.#syncHidden()
  }

  // -- Private --

  #selectOption(option) {
    if (option.classList.contains("tag-create-row")) {
      // Create row selected — add with no colour (user can pick dots instead)
      const name = option.dataset.name
      if (name) this.#addTag(name, null)
    } else {
      const name = option.dataset.name
      if (name) this.#addTag(name, null)
    }
  }

  #addTag(name, colour) {
    if (this.tags.has(name)) {
      this.inputTarget.value = ""
      this.#closeSuggestions()
      return
    }
    this.tags.set(name, colour || null)
    this.#appendChip(name, colour)
    this.#syncHidden()
    this.inputTarget.value = ""
    this.#closeSuggestions()
  }

  #appendChip(name, colour) {
    const chip = document.createElement("span")
    chip.className = "tag-chip"
    if (colour) {
      chip.style.color = `var(--model-color-${colour})`
      chip.style.background = `var(--model-color-${colour}-bg)`
    }
    chip.innerHTML = `${name} <button type="button" data-action="click->tag-input#removeTag" data-name="${name}">&times;</button>`
    this.chipsTarget.appendChild(chip)
  }

  #syncHidden() {
    const parts = []
    for (const [name, colour] of this.tags) {
      parts.push(colour ? `${name}:${colour}` : name)
    }
    this.hiddenTarget.value = parts.join(", ")
  }

  #closeSuggestions() {
    this.activeIndex = -1
    const frame = this.suggestionsTarget
    try { frame.hidePopover() } catch (_) { /* not open */ }
    frame.innerHTML = ""
    frame.removeAttribute("src")
  }

  get #options() {
    return Array.from(this.suggestionsTarget.querySelectorAll("li[role='option']"))
  }

  #highlightOption() {
    const options = this.#options
    options.forEach((li, i) => {
      li.classList.toggle("active", i == this.activeIndex)
    })
    if (this.activeIndex >= 0 && options[this.activeIndex]) {
      options[this.activeIndex].scrollIntoView({ block: "nearest" })
    }
  }
}
