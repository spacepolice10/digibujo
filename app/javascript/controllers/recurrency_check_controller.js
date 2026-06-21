import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    completeUrl: String,
    date: String,
    completed: Boolean
  }

  async toggle(event) {
    event.preventDefault()
    if (this.element.disabled) return

    this.element.disabled = true
    const method = this.completedValue ? "DELETE" : "POST"
    const url = new URL(this.completeUrlValue, window.location.origin)
    url.searchParams.set("date", this.dateValue)

    const token = document.querySelector("meta[name='csrf-token']")?.content
    const headers = {
      Accept: "text/vnd.turbo-stream.html",
      "X-CSRF-Token": token
    }

    try {
      const response = await fetch(url, { method, headers, credentials: "same-origin" })
      if (response.ok) {
        const html = await response.text()
        if (html && window.Turbo) window.Turbo.renderStreamMessage(html)
        return
      }

      if (response.status == 422) return
    } finally {
      this.element.disabled = false
    }
  }
}
