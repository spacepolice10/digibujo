import { Controller } from "@hotwired/stimulus"

const EXPANDED_CLASS = "is-expanded"
const COLLAPSING_CLASS = "is-collapsing"
const FLY_IN_ANIMATION = "daylog-photo-fly-in"

export default class extends Controller {
  static targets = ["card", "shell"]
  static values = {
    url: String,
    lazy: Boolean,
  }

  #loadPromise = null

  toggle() {
    if (this.expanded) {
      this.collapse()
    } else {
      this.expand()
    }
  }

  async expand() {
    if (this.expanded) return

    await this.#ensureCard()
    if (!this.hasCardTarget || this.expanded) return

    this.cardTarget.classList.remove(COLLAPSING_CLASS)
    this.cardTarget.classList.add(EXPANDED_CLASS)
    this.cardTarget.setAttribute("aria-expanded", "true")
  }

  collapse() {
    if (!this.expanded) return

    this.cardTarget.classList.remove(EXPANDED_CLASS)
    this.cardTarget.classList.add(COLLAPSING_CLASS)
    this.cardTarget.setAttribute("aria-expanded", "false")
  }

  collapseOutside(event) {
    if (!this.hasCardTarget) return
    if (this.#isPhotoChrome(event.target)) return

    this.collapse()
  }

  settle(event) {
    if (event.animationName != FLY_IN_ANIMATION) return
    if (!this.hasCardTarget) return

    this.cardTarget.classList.remove(COLLAPSING_CLASS)

    if (this.lazyValue && !this.expanded) this.#unloadCard()
  }

  // Toolbar / header controls live inside the controller element; keep their
  // clicks from toggling the card or collapsing via the document listener.
  stop(event) {
    event.stopPropagation()
  }

  get expanded() {
    return this.hasCardTarget && this.cardTarget.classList.contains(EXPANDED_CLASS)
  }

  async #ensureCard() {
    if (this.hasCardTarget) return
    if (!this.lazyValue || !this.hasShellTarget || !this.hasUrlValue) return

    if (this.#loadPromise) return this.#loadPromise

    this.#loadPromise = this.#loadCard().finally(() => {
      this.#loadPromise = null
    })

    return this.#loadPromise
  }

  async #loadCard() {
    const response = await fetch(this.urlValue, {
      headers: {
        Accept: "text/html",
        "X-Requested-With": "XMLHttpRequest",
      },
    })
    if (!response.ok) return

    this.shellTarget.innerHTML = await response.text()
  }

  #unloadCard() {
    if (!this.hasShellTarget) return

    this.shellTarget.replaceChildren()
  }

  #isPhotoChrome(target) {
    return target.closest(".daylog--photo-card, .daylog--picture")
  }
}
