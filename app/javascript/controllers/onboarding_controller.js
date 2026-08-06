import { Controller } from "@hotwired/stimulus"

// Full-screen snap carousel for onboarding: next/previous/jumpToLast buttons,
// arrow-key navigation, dot indicators, and the footer swap (nav → submit).
export default class extends Controller {
  static targets = ["section", "dots", "skip"]

  connect() {
    this.element.addEventListener("scroll", () => this.#sync(), { passive: true })
    const index = window.location.hash.match(/#onboarding-(\d+)/)?.[1]
    if (index) this.#scrollTo(Number(index))
    this.#sync()
  }

  next()      { this.#scrollTo(this.#index + 1) }
  previous()  { this.#scrollTo(this.#index - 1) }
  jumpToLast() { this.#scrollTo(this.#last) }

  jumpToDot(event) {
    const dot = event.target.closest("li")
    if (dot) this.#scrollTo(Number(dot.dataset.index))
  }

  get #last()  { return this.sectionTargets.length - 1 }
  get #index() {
    return Math.round(this.element.scrollLeft / this.element.clientWidth)
  }

  #scrollTo(index) {
    const target = Math.max(0, Math.min(index, this.#last))
    this.element.scrollTo({ left: target * this.element.clientWidth, behavior: "instant" })
  }

  #sync() {
    const last = this.#index === this.#last

    history.replaceState(null, "", `#onboarding-${this.#index}`)
    this.sectionTargets.forEach((section, i) => {
      section.toggleAttribute("data-active", i === this.#index)
    })
    this.dotsTarget.querySelectorAll("li").forEach((dot, i) => {
      dot.toggleAttribute("data-active", i === this.#index)
    })
  }
}