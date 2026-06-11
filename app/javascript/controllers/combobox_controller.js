import { Controller } from "@hotwired/stimulus";
import { navigateCombobox } from "helpers/combobox";

export default class extends Controller {
  static targets = ["item"];

  connect() {
    this.currentPosition = -1;
  }

  navigate(event) {
    if (event.key == "ArrowDown") {
      event.preventDefault();
      this._move("down");
    } else if (event.key == "ArrowUp") {
      event.preventDefault();
      this._move("up");
    } else if (event.key == "Enter" || event.key == " ") {
      this._activate(event);
    } else if (event.key == "Escape") {
      this.currentPosition = -1;
      this._updateItems();
    }
  }

  itemTargetConnected() {
    this.currentPosition = -1;
    this._updateItems();
  }

  itemTargetDisconnected() {
    this.currentPosition = -1;
    this._updateItems();
  }

  _activate(event) {
    if (this.currentPosition < 0) return;

    const item = this.itemTargets[this.currentPosition];
    const activatable = this._activatable(item);
    if (!activatable) return;

    event.preventDefault();
    activatable.click();
  }

  _activatable(item) {
    if (!item) return null;
    if (item.matches("a, button")) return item;
    return item.querySelector("a, button");
  }

  _move(direction) {
    this.currentPosition = navigateCombobox(
      this.currentPosition,
      direction,
      this.itemTargets.length,
    );
    this._updateItems();
  }

  _updateItems() {
    this.itemTargets.forEach((item, index) => {
      item.classList.toggle("is-active", index == this.currentPosition);
      item.setAttribute("aria-selected", index == this.currentPosition);
    });
  }
}
