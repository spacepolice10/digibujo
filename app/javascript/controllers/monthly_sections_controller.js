import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["section", "side"]
  static values = { active: { type: String, default: "days" } }

  connect() {
    let section = this.activeValue

    try {
      const stored = sessionStorage.getItem("monthly_bucket_section")
      if (stored && this.#hasSide(stored)) section = stored
    } catch (_error) {
    }

    this.activeValue = section
    this.show(section)
    this.resizeObserver = () => this.show(this.activeValue)
    window.addEventListener("resize", this.resizeObserver)
  }

  disconnect() {
    window.removeEventListener("resize", this.resizeObserver)
  }

  select(event) {
    const section = event.currentTarget.dataset.monthlySectionsSection
    if (!section) return

    this.activeValue = section
    this.show(section)

    try {
      sessionStorage.setItem("monthly_bucket_section", section)
    } catch (_error) {
    }
  }

  show(section) {
    const narrow = window.matchMedia("(max-width: 799px)").matches
    const mobilePage = this.element.closest(".monthly-bucket--page-mobile")
    const tabbed = narrow || mobilePage

    this.sectionTargets.forEach((element) => {
      const selected = element.dataset.monthlySectionsSection == section
      element.classList.toggle("monthly-bucket--monthly-section-active", selected)
      element.setAttribute("aria-selected", selected)
    })

    this.sideTargets.forEach((element) => {
      const side = element.dataset.monthlySectionsSide
      const active = side == section

      if (tabbed) {
        element.hidden = !active
      } else {
        element.hidden = false
      }
    })
  }

  #hasSide(section) {
    return this.sideTargets.some(
      (element) => element.dataset.monthlySectionsSide == section,
    )
  }
}
