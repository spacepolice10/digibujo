import { Controller } from "@hotwired/stimulus"

const VT_CLASS = "is-composer-expanding"
const STORAGE_KEY = "composer-expand-type"

// Shared-element expand: create-button shell ↔ page-form shell.
// Only one element may hold the view-transition-name at a time (many dock
// buttons share a type on monthlylog), so we mark the clicked button; CSS
// puts the name on its ::before (background only — no stretched label text).
export default class extends Controller {
  connect() {
    this.boundClick = (event) => this.#onClick(event)
    this.boundBeforeRender = (event) => this.#onBeforeRender(event)
    this.boundLoad = () => this.#onLoad()

    document.addEventListener("turbo:click", this.boundClick)
    document.addEventListener("turbo:before-render", this.boundBeforeRender)
    document.addEventListener("turbo:load", this.boundLoad)
  }

  disconnect() {
    document.removeEventListener("turbo:click", this.boundClick)
    document.removeEventListener("turbo:before-render", this.boundBeforeRender)
    document.removeEventListener("turbo:load", this.boundLoad)
  }

  #onClick(event) {
    if (this.#reducedMotion) return

    const link = event.target.closest("[data-composer-expand]")
    if (!link) return

    this.#clearExpanding(document)
    link.classList.add(VT_CLASS)

    const type = link.dataset.bulletType
    if (type) sessionStorage.setItem(STORAGE_KEY, type)
  }

  #onBeforeRender(event) {
    if (this.#reducedMotion) return

    const type = sessionStorage.getItem(STORAGE_KEY)
    if (!type) return

    const newBody = event.detail.newBody
    if (newBody.querySelector(".bullets-form--page")) return

    this.#clearExpanding(newBody)
    const button = newBody.querySelector(`[data-composer-expand][data-bullet-type="${CSS.escape(type)}"]`)
    if (button) button.classList.add(VT_CLASS)
  }

  #onLoad() {
    this.#clearExpanding(document)

    const pageForm = document.querySelector(".bullets-form--page")
    if (pageForm) {
      const type = pageForm.dataset.bulletType
      if (type) sessionStorage.setItem(STORAGE_KEY, type)
      return
    }

    sessionStorage.removeItem(STORAGE_KEY)
  }

  #clearExpanding(root) {
    root.querySelectorAll(`[data-composer-expand].${VT_CLASS}`).forEach((element) => {
      element.classList.remove(VT_CLASS)
    })
  }

  get #reducedMotion() {
    return matchMedia("(prefers-reduced-motion: reduce)").matches
  }
}
