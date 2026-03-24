import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "frame"]

  connect() {
    this.activeIndex = -1

    this.frameTarget.addEventListener("turbo:frame-load", () => {
      this.activeIndex = -1
      if (this.#options.length > 0) {
        this.frameTarget.showPopover()
      } else {
        this.frameTarget.hidePopover()
      }
    })
  }

  onFocus() {
    this.frameTarget.src = "/tags"
  }

  onInput() {
    clearTimeout(this._debounce)
    this._debounce = setTimeout(() => {
      const query = this.inputTarget.value.trim()
      this.frameTarget.src = query.length > 0 ? `/tags?q=${encodeURIComponent(query)}` : "/tags"
    }, 200)
  }

  onKeydown(event) {
    const options = this.#options
    const open = options.length > 0 && this.frameTarget.matches(":popover-open")

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
        const option = options[this.activeIndex]
        const name = option.dataset.name
        if (name) {
          this.dispatch("select", { detail: { name, colour: null } })
          this.#closeSuggestions()
        }
      } else {
        const name = this.inputTarget.value.replace(/,/g, "").trim().toLowerCase()
        if (name) {
          this.dispatch("select", { detail: { name, colour: null } })
          this.#closeSuggestions()
        }
      }
    }
  }

  onBlur() {
    setTimeout(() => this.#closeSuggestions(), 150)
  }

  pick(event) {
    event.preventDefault()
    const name = event.currentTarget.dataset.name
    if (name) this.dispatch("select", { detail: { name, colour: null } })
    this.inputTarget.focus()
  }

  pickColour(event) {
    event.preventDefault()
    event.stopPropagation()
    const name = event.currentTarget.dataset.name
    const colour = event.currentTarget.dataset.colour
    if (name) this.dispatch("select", { detail: { name, colour: colour || null } })
    this.inputTarget.focus()
  }

  // -- Private --

  #closeSuggestions() {
    this.activeIndex = -1
    try { this.frameTarget.hidePopover() } catch (_) { /* not open */ }
    this.frameTarget.innerHTML = ""
    this.frameTarget.removeAttribute("src")
  }

  get #options() {
    return Array.from(this.frameTarget.querySelectorAll("li[role='option']"))
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
