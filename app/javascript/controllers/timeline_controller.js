import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { searchPath: String }

  openSearch(event) {
    if (!this.hasSearchPathValue) return

    event.preventDefault()
    window.location.assign(this.searchPathValue)
  }

  selectCardFormEditor(event) {
    const editor = document.querySelector("#bullet_form trix-editor")
    if (!editor) return

    event.preventDefault()
    editor.focus()
  }
}
