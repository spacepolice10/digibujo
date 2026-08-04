import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["cell"]
  static values = { date: String }

  navigateToDate = (event) => {
    console.log(event.params)
    const {date} = event.params
    for (const target of this.cellTargets) {
        if (target.dataset.calendarDateValue === date) {
            target.setAttribute("aria-selected", "true")
        } else {
            target.setAttribute("aria-selected", "false")
        }
    }
  }
}