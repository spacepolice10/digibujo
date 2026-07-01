import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  scroll() {
    const composer = document.getElementById("bullet_composer")
    if (!composer) return

    composer.scrollIntoView({ block: "nearest" })

    const firstOption = composer.querySelector(".bullet--composer-create-button")
    firstOption?.focus({ preventScroll: true })
  }
}
