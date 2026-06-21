import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = {
    frameId: String,
  };

  connect() {
    this.submitEndHandler = (event) => this.closeOnSubmitEnd(event);
    document.addEventListener("turbo:submit-end", this.submitEndHandler);
  }

  disconnect() {
    document.removeEventListener("turbo:submit-end", this.submitEndHandler);
  }

  closeOnSubmitEnd(event) {
    if (!event.detail.success) return;

    const form = event.target;
    if (!this.isCollectForm(form)) return;
    if (!this.isFormForFrame(form)) return;

    this.closeFrame();
  }

  isCollectForm(form) {
    return form?.action?.includes("/bullets/collect");
  }

  isFormForFrame(form) {
    if (this.element.contains(form)) return true;

    const frameIdInput = form.querySelector('input[name="frame_id"]');
    return frameIdInput?.value == this.frameIdValue;
  }

  closeFrame() {
    const frame = document.getElementById(this.frameIdValue);
    if (frame?.matches(":popover-open")) frame.hidePopover();
  }
}
