import { Controller } from "@hotwired/stimulus";
import { patch } from "@rails/request.js";

export default class extends Controller {
  static targets = ["form"];

  connect() {
    this.pendingSave = null;
    this.onChange = this.onChange.bind(this);
    this.formTarget.addEventListener("lexxy:change", this.onChange);
  }

  disconnect() {
    this.clearPendingSave();
    this.formTarget.removeEventListener("lexxy:change", this.onChange);
  }

  onChange() {
    this.scheduleSave();
  }

  flush() {
    this.clearPendingSave();
    return this.save();
  }

  scheduleSave() {
    this.clearPendingSave();
    this.pendingSave = setTimeout(() => {
      this.pendingSave = null;
      this.save();
    }, 800);
  }

  clearPendingSave() {
    if (this.pendingSave) {
      clearTimeout(this.pendingSave);
      this.pendingSave = null;
    }
  }

  save() {
    const editor = this.formTarget.querySelector("lexxy-editor");
    if (!editor) return;

    const formData = new FormData(this.formTarget);
    formData.set("bucket[side_note]", editor.value);

    patch(this.formTarget.action, { body: formData }).catch((error) => {
      console.error("Side note save failed:", error);
    });
  }
}
