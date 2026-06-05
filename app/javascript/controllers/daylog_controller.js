import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["dateForm"];
  static values = {
    date: { type: String, default: "" },
  };

  switchDate(date) {
    this.dateValue = date.target.value;
    Turbo.visit(`/daylog?date=${this.dateValue}`, { action: "advance" });
  }
}
