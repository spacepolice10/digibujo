import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["file"]

  choose(event) {
    event.preventDefault()
    this.fileTarget.click()
  }

  attach() {
    if (this.fileTarget.files.length == 0) return

    this.dispatch("lock")
    this.fileTarget.form.requestSubmit()
  }

  reset() {
    if (this.fileTarget.files.length == 0) return

    this.fileTarget.value = ""
    this.dispatch("unlock")
  }
}
