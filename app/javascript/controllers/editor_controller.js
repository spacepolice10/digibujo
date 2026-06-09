import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["typePicker", "typeSelect", "previews"];

  connect() {
    this.syncType();
  }

  disconnect() {
    console.log("disconnect");
  }

  handleKeydown(event) {
    if (event.isComposing) return;

    if (event.altKey && event.shiftKey && event.key == "Tab") {
      this.cycleType(event);
      return;
    }

    if (event.key == "Enter") {
      this.submitByReturn(event);
    }
  }

  submitByReturn(event) {
    event.preventDefault();
    this.element.requestSubmit();
  }

  cycleType(event) {
    event.preventDefault();

    const options = Array.from(this.typeSelectTarget.options);
    const currentIndex = this.typeSelectTarget.selectedIndex;
    const nextIndex = (currentIndex + 1) % options.length;

    this.typeSelectTarget.selectedIndex = nextIndex;
    this.typeSelectTarget.dispatchEvent(new Event("change", { bubbles: true }));
    this.syncType();
  }

  syncType() {
    if (!this.hasTypePickerTarget || !this.hasTypeSelectTarget) return;

    this.typePickerTarget.dataset.bulletType =
      this.typeSelectTarget.value.toLowerCase();
  }
}
