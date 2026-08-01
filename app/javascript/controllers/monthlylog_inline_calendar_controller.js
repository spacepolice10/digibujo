import { Controller } from "@hotwired/stimulus"

// Scroll today's day chip into view when the mobile inline calendar connects.
export default class extends Controller {
  connect() {
    requestAnimationFrame(() => {
      const today = this.element.querySelector(".monthlylog--date-cell-inline.is-current")
      const selected = this.element.querySelector(".monthlylog--date-cell-inline.is-selected")
      ;(today || selected)?.scrollIntoView({
        inline: "center",
        block: "nearest",
        behavior: "auto"
      })
    })
  }
}
