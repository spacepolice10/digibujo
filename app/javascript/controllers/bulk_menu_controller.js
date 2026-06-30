import { Controller } from "@hotwired/stimulus";
import { debounce } from "helpers/debounce";

const SEARCH_DEBOUNCE_MS = 150;

const ACTION_REQUIREMENTS = {
  requirePinnable: "pinnable",
  requireCompletable: "completable",
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
    popsPickerUrl: { type: String, default: "/bullets/pop/new" },
    collectsPickerUrl: { type: String, default: "/bullets/collect/new" },
  };

  #searchAbort = null;

  connect() {
    this.beforeVisitHandler = () => this.#reset();
    this.submitEndHandler = (event) => this.#handleSubmitEnd(event);
    document.addEventListener("turbo:before-visit", this.beforeVisitHandler);
    document.addEventListener("turbo:submit-end", this.submitEndHandler);
    this.#syncSelectMode();
  }

  disconnect() {
    document.removeEventListener("turbo:before-visit", this.beforeVisitHandler);
    document.removeEventListener("turbo:submit-end", this.submitEndHandler);
    this.#cancelPendingSearch();
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
    this.#updateBulkActions();
  }

  selectModeValueChanged() {
    this.menuTarget.focus();
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
    this.#openPopsPicker();
  }

  openCollectsPicker() {
    this.#openCollectsPicker();
  }

  searchCollects(event) {
    this.#cancelPendingSearch();
    this.#searchAbort = new AbortController();
    this.#debouncedSearchCollects(event.target);
  }

  selectAndOpenCollects({ params: { bulletId } }) {
    if (!bulletId) return;

    this.idListValue = [bulletId];
    this.checkboxTargets.forEach((checkbox) => {
      checkbox.checked = checkbox.value == bulletId;
    });
    this.#openCollectsPicker();
  }

  clear() {
    this.#reset();
  }

  escape(event) {
    if (event?.defaultPrevented) return;
    if (this.idListValue.length == 0) return;
    if (this.#isPickerOpen()) return;

    this.#clearSelection();
  }

  #isPickerOpen() {
    const pickers = [];
    if (this.hasPopsDropdownTarget) pickers.push(this.popsDropdownTarget);
    if (this.hasCollectsDropdownTarget) pickers.push(this.collectsDropdownTarget);
    return pickers.some((picker) => picker.matches(":popover-open"));
  }

  #debouncedSearchCollects = debounce((input) => this.#performCollectsSearch(input), SEARCH_DEBOUNCE_MS);

  async #performCollectsSearch(input) {
    const form = input.form;
    const url = new URL(form.action, window.location.origin);
    const params = new URLSearchParams(new FormData(form));

    params.set("q", input.value.trim());
    params.delete("collections_page");
    params.delete("sprints_page");
    url.search = params.toString();

    const response = await fetch(url.toString(), {
      signal: this.#searchAbort.signal,
      headers: { Accept: "text/vnd.turbo-stream.html" },
    }).catch(() => null);
    if (!response || !response.ok) return;

    const stream = await response.text().catch(() => "");
    if (stream && window.Turbo) window.Turbo.renderStreamMessage(stream);
  }

  #cancelPendingSearch() {
    this.#searchAbort?.abort();
    this.#searchAbort = null;
  }

  #openPopsPicker() {
    this.#loadPicker(this.popsDropdownTarget, this.popsPickerUrlValue);
  }

  #openCollectsPicker() {
    this.#loadPicker(this.collectsDropdownTarget, this.collectsPickerUrlValue);
  }

  #loadPicker(frame, baseUrl) {
    if (this.idListValue.length == 0) return;

    this.#openPicker(frame, this.#pickerLink(baseUrl, this.idListValue));
  }

  #pickerLink(baseUrl, bulletIds, params = {}) {
    const url = new URL(baseUrl, window.location.origin);
    url.searchParams.set("bullet_ids", bulletIds.join(","));
    Object.entries(params).forEach(([key, value]) => url.searchParams.set(key, value));
    return `${url.pathname}${url.search}`;
  }

  #openPicker(frame, src) {
    if (!frame) return;

    if (frame.src != src) frame.src = src;
    if (!frame.hasAttribute("popover")) return;
    if (!frame.matches(":popover-open")) frame.showPopover();
  }

  #closePicker(frame) {
    if (frame?.matches(":popover-open")) frame.hidePopover();
  }

  #reset() {
    this.#closePicker(this.popsDropdownTarget);
    this.#closePicker(this.collectsDropdownTarget);
    this.#clearSelection();
  }

  #clearSelection() {
    this.idListValue = [];
    this.checkboxTargets.forEach((checkbox) => {
      checkbox.checked = false;
    });
  }

  #handleSubmitEnd(event) {
    if (!event.detail.success) return;

    const form = event.target;
    if (!form?.action) return;

    const isCollect = form.action.includes("/bullets/collect");
    const isPop =
      form.action.includes("/bullets/pop") &&
      form.method?.toLowerCase() == "post";
    const isMenuBulk =
      this.hasMenuTarget &&
      this.menuTarget.contains(form) &&
      form.method?.toLowerCase() != "get";

    if (isCollect || isPop || isMenuBulk) this.#reset();
  }

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
    };
  }

  #uniformTrait(checkboxes, datasetKey) {
    const values = checkboxes.map((checkbox) => checkbox.dataset[datasetKey]);
    if (values.some((value) => !value)) return null;
    if (values.some((value) => value != values[0])) return null;
    return values[0];
  }

  #actionApplies(action, traits) {
    if (!traits) return false;

    return Object.entries(ACTION_REQUIREMENTS).every(([requirement, trait]) => {
      const expected = action.dataset[requirement];
      if (!expected) return true;
      return traits[trait] == expected;
    });
  }

  #syncSelectMode() {
    if (!this.hasListTarget) return;

    if (this.selectModeValue) {
      this.listTarget.dataset.mode = "select";
    } else {
      delete this.listTarget.dataset.mode;
    }
  }
}
