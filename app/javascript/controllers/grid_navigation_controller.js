import { Controller } from "@hotwired/stimulus";
import { navigateGrid } from "helpers/grid_navigation";

export default class extends Controller {
  static values = { columns: Number };
  static targets = ["item"];

  connect() {
    this.currentPosition = 0;
    this.detailsElement = this.element.closest("details");
    this.initTabindex();
    if (this.element.hasAttribute("popover")) {
      this._onToggle = this.onToggle.bind(this);
      this.element.addEventListener("toggle", this._onToggle);
    }
    if (this.detailsElement) {
      this._onDetailsToggle = this.onDetailsToggle.bind(this);
      this.detailsElement.addEventListener("toggle", this._onDetailsToggle);
    }
  }

  disconnect() {
    if (this._onToggle) {
      this.element.removeEventListener("toggle", this._onToggle);
    }
    if (this._onDetailsToggle && this.detailsElement) {
      this.detailsElement.removeEventListener("toggle", this._onDetailsToggle);
    }
  }

  onToggle(event) {
    if (event.newState != "open") return;
    this.currentPosition = 0;
    requestAnimationFrame(() => this.moveTo(this.currentPosition));
  }

  navigate(event) {
    if (!this.isNavigable()) return;

    const directions = {
      ArrowLeft: "left",
      ArrowRight: "right",
      ArrowUp: "up",
      ArrowDown: "down",
    };
    const direction = directions[event.key];
    if (!direction) return;

    event.preventDefault();

    const next = navigateGrid(
      this.currentPosition,
      direction,
      this.columnsValue,
      this.itemTargets.length,
    );
    this.moveTo(next);
  }

  syncPosition(event) {
    if (!this.isNavigable()) return;

    const position = this.itemTargets.indexOf(event.target);
    if (position == -1) return;

    this.currentPosition = position;
    this.initTabindex();
  }

  moveTo(position) {
    this.currentPosition = position;
    this.initTabindex();
    this.itemTargets[position]?.focus();
  }

  itemTargetConnected() {
    this.currentPosition = 0;
    this.initTabindex();
  }

  itemTargetDisconnected() {
    this.initTabindex();
  }

  initTabindex() {
    const items = this.itemTargets;
    if (!items.length) return;

    if (!this.isNavigable()) {
      items.forEach((item) => item.setAttribute("tabindex", "-1"));
      return;
    }

    this.currentPosition = Math.min(this.currentPosition, items.length - 1);
    items.forEach((item, index) => {
      item.setAttribute("tabindex", index == this.currentPosition ? "0" : "-1");
    });
  }

  onDetailsToggle() {
    if (!this.isNavigable()) {
      this.itemTargets.forEach((item) => {
        item.setAttribute("tabindex", "-1");
        if (item == document.activeElement) item.blur();
      });
    }

    this.initTabindex();
  }

  isNavigable() {
    return !this.detailsElement || this.detailsElement.open;
  }
}
