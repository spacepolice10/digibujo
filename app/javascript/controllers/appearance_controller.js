import { Controller } from "@hotwired/stimulus"
import { post } from "@rails/request.js"

export default class extends Controller {
  static values = { url: String }

  apply(event) {
    const appearance = event.target.value
    document.documentElement.dataset.appearance = appearance

    post(this.urlValue, { body: { appearance } })
      .then((response) => {
        if (!response.ok) console.error("Appearance persist failed:", response.statusCode)
      })
      .catch((error) => console.error("Appearance persist failed:", error))
  }
}
