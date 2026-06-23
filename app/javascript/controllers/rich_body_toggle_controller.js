import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["preview", "editor"]

  show() {
    this.previewTarget.hidden = true
    this.editorTarget.hidden = false
    const editor = this.editorTarget.querySelector("lexxy-editor")
    queueMicrotask(() => editor?.focus())
  }
}
