import { Controller } from "@hotwired/stimulus";

const TYPE_SHORTCUTS = {
  "* ": "task",
  "- ": "note",
  "!": "event",
  ">": "daylog",
};

export default class extends Controller {
  static targets = ["fieldsFrame"];

  connect() {
    this.element.dataset.loading = "";
    requestAnimationFrame(() =>
      requestAnimationFrame(() => {
        delete this.element.dataset.loading;
      }),
    );
  }

  loadFields(event) {
    if (!this.hasFieldsFrameTarget) return;
    if (event.target.name != "cardable_type") return;
    const value = event.target.value;
    if (value) {
      this.fieldsFrameTarget.src = `/cards/fields/${value}`;
    } else {
      this.fieldsFrameTarget.removeAttribute("src");
      this.fieldsFrameTarget.innerHTML = "";
    }
  }

  detectTypeShortcut(event) {
    const editor = event.target.editor;
    const text = editor.getDocument().toString();
    for (const [shortcut, type] of Object.entries(TYPE_SHORTCUTS)) {
      if (text.startsWith(shortcut)) {
        const radio = this.element.querySelector(
          `input[name="cardable_type"][value="${type}"]`,
        );
        if (radio) {
          radio.checked = true;
          radio.dispatchEvent(new Event("change", { bubbles: true }));
        }
        editor.setSelectedRange([0, shortcut.length]);
        editor.deleteInDirection("forward");
        break;
      }
    }
  }

  submit(event) {
    event.preventDefault();
    this.element.requestSubmit();
  }
}
