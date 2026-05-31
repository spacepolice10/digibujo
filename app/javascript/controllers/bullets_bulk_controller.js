import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "menu",
    "checkbox",
    "idsInput",
    "count",
    "pinAction",
    "unpinAction"
  ]

  static values = {
    ids: { type: Array, default: [] }
  }

  connect() {
    this.beforeVisitHandler = () => this.clearSelection()
    document.addEventListener("turbo:before-visit", this.beforeVisitHandler)

    this.collectSubmitHandler = (event) => {
      if (!event.detail.success) return
      const form = event.target
      if (!form?.action?.includes("/bullets/collect")) return

      this.clearSelection()
    }
    document.addEventListener("turbo:submit-end", this.collectSubmitHandler)

    this.popSubmitHandler = (event) => {
      if (!event.detail.success) return
      const form = event.target
      if (!form?.action?.includes("/bullets/pop")) return
      if (form.method?.toLowerCase() != "post") return

      document.getElementById("pop_picker")?.hidePopover()
      this.clearSelection()
    }
    document.addEventListener("turbo:submit-end", this.popSubmitHandler)
  }

  disconnect() {
    document.removeEventListener("turbo:before-visit", this.beforeVisitHandler)
    document.removeEventListener("turbo:submit-end", this.collectSubmitHandler)
    document.removeEventListener("turbo:submit-end", this.popSubmitHandler)
  }

  toggle(event) {
    const checkbox = event.currentTarget
    const id = checkbox.value

    if (checkbox.checked) {
      if (!this.idsValue.includes(id)) this.idsValue = [...this.idsValue, id]
    } else {
      this.idsValue = this.idsValue.filter((value) => value != id)
    }
  }

  idsValueChanged() {
    const csv = this.idsValue.join(",")

    this.idsInputTargets.forEach((input) => {
      input.value = csv
    })

    if (this.hasMenuTarget) {
      this.menuTarget.hidden = this.idsValue.length == 0
    }

    if (this.hasCountTarget) {
      this.countTarget.textContent = `${this.idsValue.length} selected`
    }

    this.updatePinActions()
  }

  checkboxTargetConnected(checkbox) {
    checkbox.checked = this.idsValue.includes(checkbox.value)
    this.updatePinActions()
  }

  clear() {
    this.clearSelection()
  }

  clearSelection() {
    this.idsValue = []
    this.checkboxTargets.forEach((checkbox) => {
      checkbox.checked = false
    })
  }

  updatePinActions() {
    const checked = this.checkboxTargets.filter((checkbox) => checkbox.checked)
    const anyPinned = checked.some((checkbox) => checkbox.hasAttribute("data-pinned"))
    const anyUnpinned = checked.some((checkbox) => !checkbox.hasAttribute("data-pinned"))

    if (this.hasPinActionTarget) {
      this.pinActionTarget.hidden = anyPinned || checked.length == 0
    }

    if (this.hasUnpinActionTarget) {
      this.unpinActionTarget.hidden = anyUnpinned || checked.length == 0
    }
  }

  submitEnd(event) {
    if (!this.hasMenuTarget || !this.menuTarget.contains(event.target)) return
    if (!event.detail.success) return

    const form = event.target
    if (form.method?.toLowerCase() == "get") return

    this.clearSelection()
  }

  stopPropagation(event) {
    event.stopPropagation()
  }
}
