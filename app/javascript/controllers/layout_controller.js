import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = { searchPath: String, dailiesPath: String };

  openSearch(event) {
    if (!this.hasSearchPathValue) return;
    event.preventDefault();
    window.location.assign(this.searchPathValue);
  }

  openDailies(event) {
    if (!this.hasDailiesPathValue) return;
    event.preventDefault();
    window.location.assign(this.dailiesPathValue);
  }

  createBulletFormEditor(event) {
    const editor = document.querySelector("#bullet_form trix-editor");
    if (!editor) {
      document.querySelector("#new_bullet_form_trigger")?.click();
      return;
    }
    editor.focus();
    event.preventDefault();
  }
}
