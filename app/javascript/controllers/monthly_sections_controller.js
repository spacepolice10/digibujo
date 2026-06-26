import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["section", "side"]
  static values = { active: { type: String, default: "days" } }

  connect() {
    this.show(this.activeValue)
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

    this.sectionTargets.forEach((element) => {
      const selected = element.dataset.monthlySectionsSection == section
      element.classList.toggle("monthly-bucket--monthly-section-active", selected)
      element.setAttribute("aria-selected", selected)
    })

    this.sideTargets.forEach((element) => {
      const side = element.dataset.monthlySectionsSide
      const active = side == section

      if (narrow) {
        element.hidden = !active
      } else {
        element.hidden = false
      }
    })
  }
}
