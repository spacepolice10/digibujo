import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["binding"];

  keydown(event) {
    for (const binding of this.bindingTargets) {
      const combo = binding.dataset.hotkeyKeysValue;
      if (!combo || !this.matches(event, combo)) continue;

      event.preventDefault();
      this.trigger(binding);
      break;
    }
  }

  matches(event, combo) {
    const tokens = combo.toLowerCase().split("+").map((token) => token.trim()).filter(Boolean);
    const keyToken = tokens.find((token) => !["mod", "meta", "ctrl", "shift", "alt"].includes(token));
    const key = event.key.toLowerCase();

    const wantsMod = tokens.includes("mod");
    const wantsMeta = tokens.includes("meta");
    const wantsCtrl = tokens.includes("ctrl");
    const wantsShift = tokens.includes("shift");
    const wantsAlt = tokens.includes("alt");

    const modMatch = !wantsMod || event.metaKey || event.ctrlKey;
    const metaMatch = !wantsMeta || event.metaKey;
    const ctrlMatch = !wantsCtrl || event.ctrlKey;
    const shiftMatch = wantsShift == event.shiftKey;
    const altMatch = wantsAlt == event.altKey;
    const keyMatch = !keyToken || key == keyToken;

    return modMatch && metaMatch && ctrlMatch && shiftMatch && altMatch && keyMatch;
  }

  trigger(binding) {
    const action = binding.dataset.hotkeyActionValue || "click";
    const selector = binding.dataset.hotkeySelectorValue;
    const target = selector ? document.querySelector(selector) : binding;
    if (!target) return;

    if (action == "focus") {
      target.focus();
      return;
    }

    if (action == "dispatch") {
      const eventName = binding.dataset.hotkeyEventValue;
      if (!eventName) return;
      this.dispatch(eventName, { target });
      return;
    }

    target.click();
  }
}
