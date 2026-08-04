import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["cell"]
  static values = { currentDate: String, date: String }

  connect() {
    const target = this.cellTargets.find(target => target.dataset.calendarDateParam === this.dateValue)
    if (target) {
      target.scrollIntoView({ behavior: "smooth", block: "start" })
    }
  }

  navigateToDate = (event) => {
    const {date} = event.params
    for (const target of this.cellTargets) {
        if (target.dataset.calendarDateParam == date) {
            target.setAttribute("aria-selected", "true")
        } else {
            target.setAttribute("aria-selected", "false")
        }
    }
  }
}