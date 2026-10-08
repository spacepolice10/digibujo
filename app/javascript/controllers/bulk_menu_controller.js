import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = [
    "list",
    "menu",
    "checkbox",
    "idList",
    "amount",
    "complete",
    "uncomplete",
    "publish",
    "unpublish",
    "popsDialog",
    "collectsDialog",
  ];

  static values = {
    idList: { type: Array, default: [] },
    selectMode: { type: Boolean, default: false },
    popsPickerPath: { type: String, default: "/bullets/postpone/new" },
    collectsPickerPath: { type: String, default: "/bullets/collect/new" },
  };

  connect() {
    this.beforeVisitHandler = () => this.#restore();
    this.submitEndHandler = (event) => this.#handleSubmitEnd(event);
    document.addEventListener("turbo:before-visit", this.beforeVisitHandler);
    document.addEventListener("turbo:submit-end", this.submitEndHandler);
    this.#syncSelectMode();
  }

  disconnect() {
    document.removeEventListener("turbo:before-visit", this.beforeVisitHandler);
    document.removeEventListener("turbo:submit-end", this.submitEndHandler);
  }

  toggle(event) {
    const checkbox = event.currentTarget;
    if (checkbox.closest("[data-bulk-menu-ignore]")) {
      checkbox.checked = false;
      return;
    }
    const id = checkbox.value;

    if (checkbox.checked) {
      if (!this.idListValue.includes(id))
        this.idListValue = [...this.idListValue, id];
    } else {
      this.idListValue = this.idListValue.filter((value) => value != id);
    }
  }

  idListValueChanged() {
    const csv = this.idListValue.join(",");

    this.idListTargets.forEach((input) => {
      input.value = csv;
    });

    if (this.hasMenuTarget) {
      this.menuTarget.hidden = this.idListValue.length == 0;
    }

    if (this.hasAmountTarget) {
      this.amountTarget.textContent = `${this.idListValue.length} selected`;
    }

    if (this.hasMenuTarget && this.idListValue.length > 0) {
      this.menuTarget.focus({ preventScroll: true });
    }

    this.selectModeValue = this.idListValue.length > 0;
    this.#syncStatusActions();
  }

  selectModeValueChanged() {
    this.#syncSelectMode();
  }

  checkboxTargetConnected(checkbox) {
    checkbox.checked = this.idListValue.includes(checkbox.value);
    this.#syncStatusActions();
  }

  checkboxTargetDisconnected(checkbox) {
    if (!checkbox.checked) return;

    this.idListValue = this.idListValue.filter((value) => value != checkbox.value);
  }

  idListTargetConnected(input) {
    input.value = this.idListValue.join(",");
  }

  openPopsPicker() {
    this.#openPicker(this.popsDialogTarget, this.popsPickerPathValue);
  }

  openCollectsPicker() {
    this.#openPicker(this.collectsDialogTarget, this.collectsPickerPathValue);
  }

  clear() {
    this.#restore();
  }

  escape(event) {
    if (event.defaultPrevented) return;
    if (this.idListValue.length == 0) return;

    // An open picker closes itself natively — keep the selection intact.
    if (this.#isPickerOpen()) return;

    this.#cleanupSelection();
  }

  // =====================================================================
  // Picker dialogs
  // =====================================================================

  #pickerFrames() {
    const frames = [];
    if (this.haspopsDialogTarget) frames.push(this.popsDialogTarget);
    if (this.hascollectsDialogTarget) frames.push(this.collectsDialogTarget);
    return frames;
  }

  #dialogFor(frame) {
    return frame.closest("dialog");
  }

  #openPicker(frame, path) {
    if (this.idListValue.length == 0) return;

    const url = new URL(path, window.location.origin);
    url.searchParams.set("bullet_ids", this.idListValue.join(","));
    frame.src = url.pathname + url.search;

    const dialog = this.#dialogFor(frame);
    if (!dialog || dialog.open) return;

    try {
      dialog.showModal();
    } catch (error) {
      if (error.name != "InvalidStateError") throw error;

      dialog.close();
      dialog.showModal();
    }
  }

  #closePickers() {
    this.#pickerFrames().forEach((frame) => {
      const dialog = this.#dialogFor(frame);
      if (dialog?.open) dialog.close();
    });
  }

  #isPickerOpen() {
    return this.#pickerFrames().some((frame) => {
      const dialog = this.#dialogFor(frame);
      return dialog?.open ?? false;
    });
  }

  // =====================================================================
  // Form submit + selection reset
  // =====================================================================

  #handleSubmitEnd(event) {
    if (!event.detail.success) return;

    const form = event.target;
    if (!form?.action) return;

    const isPop =
      form.action.includes("/bullets/postpone") &&
      form.method?.toLowerCase() == "post";
    const isMenuBulk =
      this.hasMenuTarget &&
      this.menuTarget.contains(form) &&
      form.method?.toLowerCase() != "get";

    // Collect stays open so the row can flip to its check icon; the user
    // closes it via the dialog chrome button.
    if (isPop || isMenuBulk) this.#restore();
  }

  #restore() {
    this.#closePickers();
    this.#cleanupSelection();
  }

  #cleanupSelection() {
    this.idListValue = [];
    this.checkboxTargets.forEach((checkbox) => {
      checkbox.checked = false;
    });
  }

  // =====================================================================
  // Status actions (complete / publish)
  // =====================================================================

  #syncStatusActions() {
    const checked = this.checkboxTargets.filter((checkbox) => checkbox.checked);
    const done = this.#sharedDataset(checked, "bulkDone");
    const published = this.#sharedDataset(checked, "bulkPublished");

    if (this.hasCompleteTarget) this.completeTarget.hidden = done != "false";
    if (this.hasUncompleteTarget) this.uncompleteTarget.hidden = done != "true";
    if (this.hasPublishTarget) this.publishTarget.hidden = published != "false";
    if (this.hasUnpublishTarget) this.unpublishTarget.hidden = published != "true";
  }

  #sharedDataset(checkboxes, key) {
    if (checkboxes.length == 0) return null;

    const value = checkboxes[0].dataset[key];
    return checkboxes.every((checkbox) => checkbox.dataset[key] == value)
      ? value
      : null;
  }

  // =====================================================================
  // Select mode sync
  // =====================================================================

  #syncSelectMode() {
    if (!this.hasListTarget) return;

    if (this.selectModeValue) {
      this.listTarget.dataset.mode = "select";
    } else {
      delete this.listTarget.dataset.mode;
    }
  }
}
