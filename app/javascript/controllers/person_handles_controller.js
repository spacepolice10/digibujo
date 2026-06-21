import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["list", "template", "row", "platformField", "destroyField", "dataField"];

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
    const row = event.target.closest("[data-person-handles-target='row']");
    if (!row) return;

    const destroyField = row.querySelector("[data-person-handles-target='destroyField']");
    if (destroyField) {
      destroyField.checked = true;
      row.hidden = true;
      return;
    }

    row.remove();
  }

  kindChanged(event) {
    const row = event.target.closest("[data-person-handles-target='row']");
    if (!row) return;

    const platformField = row.querySelector("[data-person-handles-target='platformField']");
    if (platformField) {
      platformField.hidden = event.target.value != "handle";
    }

    const dataField = row.querySelector("[data-person-handles-target='dataField']");
    if (!dataField) return;

    if (event.target.value == "email") {
      dataField.type = "email";
      dataField.autocomplete = "email";
      dataField.placeholder = "";
    } else if (event.target.value == "phone") {
      dataField.type = "tel";
      dataField.autocomplete = "tel";
      dataField.placeholder = "";
    } else {
      dataField.type = "text";
      dataField.autocomplete = "off";
      dataField.placeholder = "Handle or username";
    }
  }
}
