import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["submit"]

  submitIfCodeEntered(event) {
    console.log("code entered", event.target.value)
    if (event.target.value.length == 6) {
      console.log("submitted")
      this.submitTarget.click()
    }
  }

  submitIfCodePasted(event) {
    console.log("code pasted", event.clipboardData.getData("text").length)
    // if (event.clipboardData.getData("text").length == 6) {
    //     console.log(this.element)
    //   this.submitTarget.click()
    //   console.log("submitted")
    // }
  }
}
