import { Controller } from "@hotwired/stimulus"

const EXPANDED_CLASS = "is-expanded"
const COLLAPSING_CLASS = "is-collapsing"
const DURATION_MS = 450

export default class extends Controller {
  toggle() {
    if (this.expanded) {
      this.collapse()
    } else {
      this.expand()
    }
  }

  expand() {
    if (this.element.classList.contains(COLLAPSING_CLASS)) return
    this.element.classList.add(EXPANDED_CLASS)
  }

  collapse() {
    if (!this.expanded) return
    this.element.classList.remove(EXPANDED_CLASS)
    this.element.classList.add(COLLAPSING_CLASS)
    setTimeout(() => {
      this.element.classList.remove(COLLAPSING_CLASS)
    }, DURATION_MS)
  }

  collapseOutside(event) {
    if (event.target.closest(".daylog--photo-card, .daylog--metadata-content")) return
    this.collapse()
  }

  get expanded() {
    return this.element.classList.contains(EXPANDED_CLASS)
  }
}
