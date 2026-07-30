import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { numberUrl: String }

  connect() {
    this.fetchNumber()
  }

  async fetchNumber() {
    try {
      const response = await fetch(this.numberUrlValue)
      const { number } = await response.json()
      console.log(number)
      if (number > 0) {
        this.element.querySelector('#triage_chip_button').hidden = false
        this.element.querySelector('#triage_chip_number').textContent = number
      } else {
        this.element.querySelector('#triage_chip_button').hidden = true
        this.element.querySelector('#triage_chip_number').textContent = '0'
      }
    } catch (e) {
      console.error(e)
    }
  }
}
