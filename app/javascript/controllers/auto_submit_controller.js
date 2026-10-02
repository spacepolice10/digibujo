import { Controller } from "@hotwired/stimulus"

// Submits the form it is attached to. Wire `submit` to any event, e.g.
//   input->auto-submit#submit   change->auto-submit#submit
// With `data-auto-submit-length-value="6"` the submit only fires once the
// event target's value has at least that many characters (pasted input included).
export default class extends Controller {
  static values = { length: Number }

  submit(event) {
    if (this.lengthValue > 0 && event.target.value.length < this.lengthValue) return

    this.element.requestSubmit()
  }
}
