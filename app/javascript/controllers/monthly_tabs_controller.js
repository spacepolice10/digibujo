import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]
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
    const tab = event.currentTarget.dataset.monthlyTabsTab
    if (!tab) return

    this.activeValue = tab
    this.show(tab)

    try {
      sessionStorage.setItem("monthly_bucket_tab", tab)
    } catch (_error) {
    }
  }

  show(tab) {
    const narrow = window.matchMedia("(max-width: 799px)").matches

    this.tabTargets.forEach((element) => {
      const selected = element.dataset.monthlyTabsTab == tab
      element.classList.toggle("monthly-bucket--tab-active", selected)
      element.setAttribute("aria-selected", selected)
    })

    this.panelTargets.forEach((element) => {
      const panel = element.dataset.monthlyTabsPanel
      const active = panel == tab

      if (narrow) {
        element.hidden = !active
      } else {
        element.hidden = false
      }
    })
  }
}
