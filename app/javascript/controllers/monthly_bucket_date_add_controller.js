import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = {
    frameId: String,
    newUrl: String,
    popsOn: String,
  };

  pick() {
    const type = this.element.value;
    if (!type) return;

    const frame = document.getElementById(this.frameIdValue);
    if (!frame) return;

    const url = new URL(this.newUrlValue, window.location.origin);
    url.searchParams.set("bulletable_type", type);
    if (this.popsOnValue) url.searchParams.set("pops_on", this.popsOnValue);

    frame.src = `${url.pathname}${url.search}`;

    this.element.selectedIndex = 0;
  }
}
