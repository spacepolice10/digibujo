import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["list", "template", "rail", "platformForm", "destroyForm", "dataForm"];

  add() {
    const content = this.templateTarget.content.cloneNode(true);
    const index = Date.now().toString();

    content.querySelectorAll("[name]").forEach((element) => {
      element.name = element.name.replace(/NEW_RECORD/g, index);
    });

    content.querySelectorAll("[id]").forEach((element) => {
      element.id = element.id.replace(/NEW_RECORD/g, index);
    });

    content.querySelectorAll("label[for]").forEach((element) => {
      element.htmlFor = element.htmlFor.replace(/NEW_RECORD/g, index);
    });

    this.listTarget.appendChild(content);
  }

  remove(event) {
    const rail = this.#railFor(event.currentTarget);
    if (!rail) return;

    const destroyForm = this.destroyFormTargets.find((field) => rail.contains(field));
    if (destroyForm) {
      destroyForm.checked = true;
      rail.hidden = true;
      return;
    }

    rail.remove();
  }

  kindChanged(event) {
    const rail = this.#railFor(event.currentTarget);
    if (!rail) return;

    const platformForm = this.platformFormTargets.find((element) => rail.contains(element));
    if (platformForm) {
      platformForm.hidden = event.currentTarget.value != "handle";
    }

    const dataForm = this.dataFormTargets.find((element) => rail.contains(element));
    if (!dataForm) return;

    if (event.currentTarget.value == "email") {
      dataForm.type = "email";
      dataForm.autocomplete = "email";
      dataForm.placeholder = "";
    } else if (event.currentTarget.value == "phone") {
      dataForm.type = "tel";
      dataForm.autocomplete = "tel";
      dataForm.placeholder = "";
    } else {
      dataForm.type = "text";
      dataForm.autocomplete = "off";
      dataForm.placeholder = "Handle or username";
    }
  }

  #railFor(element) {
    return this.railTargets.find((rail) => rail.contains(element));
  }
}
