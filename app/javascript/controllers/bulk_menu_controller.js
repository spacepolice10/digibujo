import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = [
    "list",
    "menu",
    "checkbox",
    "idList",
    "amount",
    "pinAction",
    "unpinAction",
    "completeAction",
    "uncompleteAction",
    "popsFrame",
    "collectsFrame",
    "peopleFrame",
  ];

  static values = {
    idList: { type: Array, default: [] },
    selectMode: { type: Boolean, default: false },
    popsPickerUrl: { type: String, default: "/bullets/pop/new" },
    collectsPickerUrl: { type: String, default: "/bullets/collect/new" },
    peoplePickerUrl: { type: String, default: "/bullets/person/new" },
  };

  connect() {
    this.beforeVisitHandler = () => this.clearSelection();
    document.addEventListener("turbo:before-visit", this.beforeVisitHandler);

    this.collectSubmitHandler = (event) => {
      if (!event.detail.success) return;
      const form = event.target;
      if (!form?.action?.includes("/bullets/collect")) return;

      if (this.hasCollectsFrameTarget) this.collectsFrameTarget.hidePopover();
      this.clearSelection();
    };
    document.addEventListener("turbo:submit-end", this.collectSubmitHandler);

    this.popSubmitHandler = (event) => {
      if (!event.detail.success) return;
      const form = event.target;
      if (!form?.action?.includes("/bullets/pop")) return;
      if (form.method?.toLowerCase() != "post") return;

      if (this.hasPopsFrameTarget) this.popsFrameTarget.hidePopover();
      this.clearSelection();
    };
    document.addEventListener("turbo:submit-end", this.popSubmitHandler);

    this.personSubmitHandler = (event) => {
      if (!event.detail.success) return;
      const form = event.target;
      if (!form?.action?.includes("/bullets/person")) return;

      if (this.hasPeopleFrameTarget) this.peopleFrameTarget.hidePopover();
      this.clearSelection();
    };
    document.addEventListener("turbo:submit-end", this.personSubmitHandler);

    this.syncSelectMode();
  }

  disconnect() {
    document.removeEventListener("turbo:before-visit", this.beforeVisitHandler);
    document.removeEventListener("turbo:submit-end", this.collectSubmitHandler);
    document.removeEventListener("turbo:submit-end", this.popSubmitHandler);
    document.removeEventListener("turbo:submit-end", this.personSubmitHandler);
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

    this.selectModeValue = this.idListValue.length > 0;
    this.updatePinActions();
    this.updateCompleteActions();
  }

  selectModeValueChanged() {
    this.menuTarget.focus();
    this.syncSelectMode();
  }

  checkboxTargetConnected(checkbox) {
    checkbox.checked = this.idListValue.includes(checkbox.value);
    this.updatePinActions();
    this.updateCompleteActions();
  }

  idListTargetConnected(input) {
    input.value = this.idListValue.join(",");
  }

  openPopsPicker() {
    this.openPickerFrame(this.popsFrameTarget, this.popsPickerUrlValue);
  }

  openCollectsPicker() {
    this.openPickerFrame(this.collectsFrameTarget, this.collectsPickerUrlValue);
  }

  openPeoplePicker() {
    this.openPickerFrame(this.peopleFrameTarget, this.peoplePickerUrlValue);
  }

  openPickerFrame(frame, baseUrl) {
    if (!frame || this.idListValue.length == 0) return;

    const url = new URL(baseUrl, window.location.origin);
    url.searchParams.set("bullet_ids", this.idListValue.join(","));
    const nextSrc = `${url.pathname}${url.search}`;

    if (frame.src != nextSrc) frame.src = nextSrc;
    if (!frame.hasAttribute("popover")) return;

    if (!frame.matches(":popover-open")) frame.showPopover();
  }

  clear() {
    this.clearSelection();
  }

  clearSelection() {
    this.idListValue = [];
    this.checkboxTargets.forEach((checkbox) => {
      checkbox.checked = false;
    });
  }

  updatePinActions() {
    const checked = this.checkboxTargets.filter((checkbox) => checkbox.checked);
    const anyPinned = checked.some((checkbox) =>
      checkbox.hasAttribute("data-pinned"),
    );
    const anyUnpinned = checked.some(
      (checkbox) => !checkbox.hasAttribute("data-pinned"),
    );

    if (this.hasPinActionTarget) {
      this.pinActionTarget.hidden = anyPinned || checked.length == 0;
    }

    if (this.hasUnpinActionTarget) {
      this.unpinActionTarget.hidden = anyUnpinned || checked.length == 0;
    }
  }

  updateCompleteActions() {
    const checked = this.checkboxTargets.filter((checkbox) => checkbox.checked);
    const anyNonCompletable = checked.some(
      (checkbox) => !checkbox.hasAttribute("data-completable"),
    );
    const anyDone = checked.some((checkbox) =>
      checkbox.hasAttribute("data-done"),
    );
    const anyUndone = checked.some(
      (checkbox) =>
        checkbox.hasAttribute("data-completable") &&
        !checkbox.hasAttribute("data-done"),
    );

    if (this.hasCompleteActionTarget) {
      this.completeActionTarget.hidden =
        checked.length == 0 || anyNonCompletable || anyDone;
    }

    if (this.hasUncompleteActionTarget) {
      this.uncompleteActionTarget.hidden =
        checked.length == 0 || anyNonCompletable || anyUndone;
    }
  }

  submitEnd(event) {
    if (!this.hasMenuTarget || !this.menuTarget.contains(event.target)) return;
    if (!event.detail.success) return;

    const form = event.target;
    if (form.method?.toLowerCase() == "get") return;

    this.clearSelection();
  }

  syncSelectMode() {
    if (!this.hasListTarget) return;

    if (this.selectModeValue) {
      this.listTarget.dataset.mode = "select";
    } else {
      delete this.listTarget.dataset.mode;
    }
  }
}
