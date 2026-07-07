import { Controller } from "@hotwired/stimulus"
import { post } from "@rails/request.js"

export default class extends Controller {
  static targets = ["textform"]
  static values = { selectionPath: String }

  rememberSelection(event) {
    if (!this.hasSelectionPathValue) return

    const link = event.currentTarget
    const searchableType = link.dataset.searchableType
    const searchableId = link.dataset.searchableId
    if (!searchableType || !searchableId) return

    post(this.selectionPathValue, {
      body: {
        searchable_type: searchableType,
        searchable_id: searchableId,
        query: this.textformTarget.value.trim(),
      },
      keepalive: true,
    }).catch(() => null)
  }
}
