import { Controller } from "@hotwired/stimulus"

const VT_NAME = "bullet-composer"
const STORAGE_KEY = "composer-expand-type"

// Shared-element expand: create button ↔ full-page composer.
// Only one element may hold the view-transition-name at a time (many dock
// buttons share a type on monthlylog), so we assign it on click / before-render.
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

    this.#clearInlineNames(document)
    link.style.viewTransitionName = VT_NAME

    const type = link.dataset.bulletType
    if (type) sessionStorage.setItem(STORAGE_KEY, type)
  }

  #onBeforeRender(event) {
    if (this.#reducedMotion) return

    const type = sessionStorage.getItem(STORAGE_KEY)
    if (!type) return

    const newBody = event.detail.newBody
    if (newBody.querySelector(".bullets-form--page")) return

    this.#clearInlineNames(newBody)
    const button = newBody.querySelector(`[data-composer-expand][data-bullet-type="${CSS.escape(type)}"]`)
    if (button) button.style.viewTransitionName = VT_NAME
  }

  #onLoad() {
    this.#clearInlineNames(document)

    const pageForm = document.querySelector(".bullets-form--page")
    if (pageForm) {
      const type = pageForm.dataset.bulletType
      if (type) sessionStorage.setItem(STORAGE_KEY, type)
      return
    }

    sessionStorage.removeItem(STORAGE_KEY)
  }

  #clearInlineNames(root) {
    root.querySelectorAll("[data-composer-expand]").forEach((element) => {
      if (element.style.viewTransitionName === VT_NAME) {
        element.style.viewTransitionName = ""
      }
    })
  }

  get #reducedMotion() {
    return matchMedia("(prefers-reduced-motion: reduce)").matches
  }
}
