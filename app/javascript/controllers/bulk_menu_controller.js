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
    "popsDropdown",
    "collectsDropdown",
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
    this.#openPicker(this.#popsFrame(), this.popsPickerPathValue);
  }

  openCollectsPicker() {
    this.#openPicker(this.#collectsFrame(), this.collectsPickerPathValue);
  }

  clear() {
    this.#restore();
  }

  escape(event) {
    if (event.defaultPrevented) return;
    if (this.idListValue.length == 0) return;

    if (this.#isPickerOpen()) {
      this.#hidePickers();
      return;
    }

    this.#cleanupSelection();
  }

  // =====================================================================
  // Picker popovers
  // =====================================================================

  #popsFrame() {
    if (!this.hasPopsDropdownTarget) return null;
    return this.popsDropdownTarget.querySelector("#postpone_picker_dropdown_id");
  }

  #collectsFrame() {
    if (!this.hasCollectsDropdownTarget) return null;
    return this.collectsDropdownTarget.querySelector("#collects_picker_dropdown_id");
  }

  #pickerFrames() {
    return [this.#popsFrame(), this.#collectsFrame()].filter(Boolean);
  }

  #openPicker(element, path) {
    if (!element) return;
    if (this.idListValue.length == 0) return;

    const url = new URL(path, window.location.origin);
    url.searchParams.set("bullet_ids", this.idListValue.join(","));
    element.src = url.pathname + url.search;

    if (!element.matches(":popover-open")) element.showPopover();
  }

  #hidePicker(element) {
    if (element?.matches(":popover-open")) element.hidePopover();
  }

  #hidePickers() {
    this.#pickerFrames().forEach((frame) => this.#hidePicker(frame));
  }

  #isPickerOpen() {
    return this.#pickerFrames().some((frame) => frame.matches(":popover-open"));
  }

  // =====================================================================
  // Form submit + selection reset
  // =====================================================================

  #handleSubmitEnd(event) {
    if (!event.detail.success) return;

    const form = event.target;
    if (!form?.action) return;

    const isCollect = form.action.includes("/bullets/collect");
    const isPop =
      form.action.includes("/bullets/postpone") &&
      form.method?.toLowerCase() == "post";
    const isMenuBulk =
      this.hasMenuTarget &&
      this.menuTarget.contains(form) &&
      form.method?.toLowerCase() != "get";

    if (isCollect || isPop || isMenuBulk) this.#restore();
  }

  #restore() {
    try {
      this.#hidePickers();
    } finally {
      this.#cleanupSelection();
    }
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
