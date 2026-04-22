import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["fields", "typeControls"];

  initialize() {
    this.handleBeforeFrameRender = this.handleBeforeFrameRender.bind(this);
  }

  connect() {
    this.element.dataset.loading = "";
    requestAnimationFrame(() =>
      requestAnimationFrame(() => {
        delete this.element.dataset.loading;
      }),
    );
    this.ensureSelectedType();
    this.ensureMode();
    this.fieldsTarget?.addEventListener("turbo:before-frame-render", this.handleBeforeFrameRender);
  }

  disconnect() {
    this.fieldsTarget?.removeEventListener("turbo:before-frame-render", this.handleBeforeFrameRender);
  }

  loadFields(event) {
    if (!this.hasFieldsTarget) return;
    if (event.target.name != "cardable_type") return;
    const value = event.target.value;
    if (!value) return;

    this.showFields();
    this.fieldsTarget.dataset.switching = "true";
    this.fieldsTarget.src = `/cards/fields/${value}`;
  }

  ensureSelectedType() {
    const selectedInput = this.element.querySelector('input[name="cardable_type"]:checked');
    if (selectedInput) return;

    const firstInput = this.element.querySelector('input[name="cardable_type"]');
    if (firstInput) firstInput.checked = true;
  }

  ensureMode() {
    if (!this.hasTypeControlsTarget) return;
    if (this.typeControlsTarget.dataset.mode) return;

    this.showFields();
  }

  showTypeSelector(event) {
    event?.preventDefault();
    if (!this.hasTypeControlsTarget) return;

    this.typeControlsTarget.dataset.mode = "types";
  }

  showFields() {
    if (!this.hasTypeControlsTarget) return;

    this.typeControlsTarget.dataset.mode = "fields";
  }

  selectType(event) {
    const input = event.currentTarget.querySelector('input[name="cardable_type"]');
    if (!input || !input.checked) return;

    if (this.typeControlsTarget.dataset.mode == "fields") {
      this.showTypeSelector(event);
    } else {
      this.showFields();
    }
  }

  switchType(event) {
    const typeIndex = Number.parseInt(event.key, 10) - 1;
    if (Number.isNaN(typeIndex) || typeIndex < 0) return;

    const typeRadios = Array.from(this.element.querySelectorAll('input[name="cardable_type"]'));
    const item = typeRadios[typeIndex];
    if (!item || item.checked) return;

    event.preventDefault();
    item.checked = true;
    item.dispatchEvent(new Event("change", { bubbles: true }));
  }

  submit(event) {
    event.preventDefault();
    this.element.requestSubmit();
  }

  async handleBeforeFrameRender(event) {
    if (!this.hasFieldsTarget) return;
    if (event.target != this.fieldsTarget) return;
    if (this.fieldsTarget.dataset.switching != "true") return;

    event.preventDefault();

    const currentItems = Array.from(this.fieldsTarget.children);
    await this.animateItems(currentItems, [
      { opacity: 1, transform: "translateX(0)" },
      { opacity: 0, transform: "translateX(6px)" },
    ]);

    event.detail.render(this.fieldsTarget, event.detail.newFrame);

    requestAnimationFrame(() => {
      const nextItems = Array.from(this.fieldsTarget.children);
      this.animateItems(nextItems, [
        { opacity: 0, transform: "translateX(-6px)" },
        { opacity: 1, transform: "translateX(0)" },
      ]);
    });
  }

  animateItems(items, keyframes) {
    if (items.length == 0) {
      delete this.fieldsTarget.dataset.switching;
      return Promise.resolve();
    }

    const animations = items.map((item, index) =>
      item.animate(keyframes, {
        duration: 180,
        easing: "ease",
        fill: "both",
        delay: index * 24,
      }).finished,
    );

    return Promise.allSettled(animations).finally(() => {
      delete this.fieldsTarget.dataset.switching;
    });
  }
}
