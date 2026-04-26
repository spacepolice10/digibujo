import { Controller } from "@hotwired/stimulus"
import { debounce } from "helpers/debounce"

const SEARCH_DEBOUNCE_MS = 180

export default class extends Controller {
  static targets = ["form", "input"]

  connect() {
    this.abortController = null
    this.requestToken = 0
    this.debouncedSearch = debounce(() => this.performSearch(), SEARCH_DEBOUNCE_MS)
  }

  disconnect() {
    this.cancelPendingRequest()
  }

  search() {
    this.debouncedSearch()
  }

  async performSearch() {
    const query = this.inputTarget.value.trim()
    const form = this.formTarget
    const actionUrl = form.action
    const url = new URL(actionUrl, window.location.origin)
    const params = new URLSearchParams(new FormData(form))

    params.set("q", query)
    params.delete("page")
    url.search = params.toString()

    this.cancelPendingRequest()
    const token = ++this.requestToken
    this.abortController = new AbortController()

    const response = await fetch(url.toString(), {
      signal: this.abortController.signal,
      headers: { Accept: "text/vnd.turbo-stream.html" }
    }).catch(() => null)

    if (!response || !response.ok || token != this.requestToken) return
    const turboStreamHtml = await response.text().catch(() => "")
    if (token != this.requestToken || !turboStreamHtml) return

    if (!window.Turbo) return
    window.Turbo.renderStreamMessage(turboStreamHtml)
    history.replaceState({}, "", url.toString())
  }

  cancelPendingRequest() {
    this.requestToken += 1
    if (this.abortController) this.abortController.abort()
    this.abortController = null
  }
}
