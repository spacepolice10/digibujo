import { Controller } from "@hotwired/stimulus";
import { navigateCombobox } from "helpers/combobox";

export default class extends Controller {
  static targets = ["textform", "item"];

  connect() {
    this.currentPosition = 0;
  }

  navigate(event) {
    if (event.key == "ArrowDown") {
      event.preventDefault();
      this._move("down");
    } else if (event.key == "ArrowUp") {
      event.preventDefault();
      this._move("up");
    } else if (event.key == "Enter" && this.currentPosition > 0) {
      event.preventDefault();
      this.textformTarget.value =
        this.itemTargets[this.currentPosition]?.textContent.trim();
      this.textformTarget.dispatchEvent(new Event("input", { bubbles: true }));
    } else if (event.key == "Escape") {
      this.currentPosition = 0;
      this._updateItems();
    }
  }

  itemTargetConnected() {
    this.currentPosition = 0;
    this._updateItems();
  }

  itemTargetDisconnected() {
    this.currentPosition = 0;
    this._updateItems();
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
