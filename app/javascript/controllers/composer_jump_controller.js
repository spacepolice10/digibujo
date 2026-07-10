import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { composerId: String }

  scroll() {
    const composer = document.getElementById(this.composerIdValue)
    if (!composer) return

    composer.scrollIntoView({ block: "nearest" })

    const firstOption = composer.querySelector(".bullet--composer-create-button")
    firstOption?.focus({ preventScroll: true })
  }
}
