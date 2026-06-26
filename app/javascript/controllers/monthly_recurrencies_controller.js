import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toggle"]

  connect() {
    try {
      if (sessionStorage.getItem("monthly_bucket_recurrencies_open") == "true") {
        this.open()
      }
    } catch (_error) {
    }
  }

  toggle() {
    if (this.element.classList.contains("monthly-bucket--recurrencies-open")) {
      this.close()
    } else {
      this.open()
    }
  }

  open() {
    this.element.classList.add("monthly-bucket--recurrencies-open")
    this.#syncToggle(true)

    try {
      sessionStorage.setItem("monthly_bucket_recurrencies_open", "true")
    } catch (_error) {
    }
  }

  close() {
    this.element.classList.remove("monthly-bucket--recurrencies-open")
    this.#syncToggle(false)

    try {
      sessionStorage.setItem("monthly_bucket_recurrencies_open", "false")
    } catch (_error) {
    }
  }

  #syncToggle(open) {
    if (!this.hasToggleTarget) return

    this.toggleTarget.setAttribute("aria-expanded", open)
    this.toggleTarget.setAttribute("aria-label", open ? "Hide habits" : "Show habits")
  }
}
