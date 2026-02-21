import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    stashUrl: String,
    pinUrl: String,
    archiveUrl: String,
    deleteUrl: String,
  }

  dispatch(event) {
    const action = event.target.value
    event.target.value = ""

    switch (action) {
      case "stash":
      case "unstash":
        this.#submit(this.stashUrlValue, "PATCH")
        break
      case "pin":
      case "unpin":
        this.#submit(this.pinUrlValue, "PATCH")
        break
      case "archive":
      case "unarchive":
        this.#submit(this.archiveUrlValue, "PATCH")
        break
      case "delete":
        if (confirm("Are you sure?")) {
          this.#submit(this.deleteUrlValue, "DELETE")
        }
        break
    }
  }

  #submit(url, method) {
    const form = document.createElement("form")
    form.method = "post"
    form.action = url

    const methodInput = document.createElement("input")
    methodInput.type = "hidden"
    methodInput.name = "_method"
    methodInput.value = method
    form.appendChild(methodInput)

    const tokenInput = document.createElement("input")
    tokenInput.type = "hidden"
    tokenInput.name = "authenticity_token"
    tokenInput.value = document.querySelector('meta[name="csrf-token"]').content
    form.appendChild(tokenInput)

    document.body.appendChild(form)
    form.requestSubmit()
    document.body.removeChild(form)
  }
}
