import { Controller } from "@hotwired/stimulus";

const ACTION_REQUIREMENTS = {
  requirePinnable: "pinnable",
  requireCompletable: "completable",
  requirePublishable: "publishable",
};

export default class extends Controller {
  static targets = [
    "list",
    "menu",
    "checkbox",
    "idList",
    "amount",
    "conditionalAction",
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
      this.menuTarget.focus();
    }

    this.selectModeValue = this.idListValue.length > 0;
    this.#updateBulkActions();
  }

  selectModeValueChanged() {
    this.#syncSelectMode();
  }

  checkboxTargetConnected(checkbox) {
    checkbox.checked = this.idListValue.includes(checkbox.value);
    this.#updateBulkActions();
  }

  idListTargetConnected(input) {
    input.value = this.idListValue.join(",");
  }

  openPopsPicker() {
    this.#openPicker(this.popsDropdownTarget, this.popsPickerPathValue);
  }

  openCollectsPicker() {
    this.#openPicker(this.collectsDropdownTarget, this.collectsPickerPathValue);
  }

  clear() {
    this.#restore();
  }

  escape(event) {
    if (event.defaultPrevented) return;
    if (this.idListValue.length == 0) return;

    if (this.#isPickerOpen()) {
      this.#hidePicker(this.popsDropdownTarget);
      this.#hidePicker(this.collectsDropdownTarget);
      return;
    }

    this.#cleanupSelection();
  }

  // =====================================================================
  // Picker popovers
  // =====================================================================

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

  #isPickerOpen() {
    const pickers = [];
    if (this.hasPopsDropdownTarget) pickers.push(this.popsDropdownTarget);
    if (this.hasCollectsDropdownTarget) pickers.push(this.collectsDropdownTarget);
    return pickers.some((picker) => picker.matches(":popover-open"));
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
    this.#hidePicker(this.popsDropdownTarget);
    this.#hidePicker(this.collectsDropdownTarget);
    this.#cleanupSelection();
  }

  #cleanupSelection() {
    this.idListValue = [];
    this.checkboxTargets.forEach((checkbox) => {
      checkbox.checked = false;
    });
  }

  // =====================================================================
  // Conditional bulk actions
  // =====================================================================

  #updateBulkActions() {
    const traits = this.#selectionTraits();

    this.conditionalActionTargets.forEach((action) => {
      action.hidden = !this.#actionApplies(action, traits);
    });
  }

  #selectionTraits() {
    const checked = this.checkboxTargets.filter((checkbox) => checkbox.checked);
    if (checked.length == 0) return null;

    return {
      pinnable: this.#uniformTrait(checked, "bulkPinnable"),
      completable: this.#uniformTrait(checked, "bulkCompletable"),
      publishable: this.#uniformTrait(checked, "bulkPublishable"),
    };
  }

  #uniformTrait(checkboxes, datasetKey) {
    const values = new Set(
      checkboxes.map((checkbox) => checkbox.dataset[datasetKey])
    );
    return values.size == 1 ? [...values][0] : null;
  }

  #actionApplies(action, traits) {
    if (!traits) return false;

    return Object.entries(ACTION_REQUIREMENTS).every(([requirement, trait]) => {
      const expected = action.dataset[requirement];
      if (!expected) return true;
      return traits[trait] == expected;
    });
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
