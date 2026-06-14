import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

const INTERACTIVE_SELECTOR = "a, button"
const PROJECT_ATTACHMENT_SELECTOR = 'action-text-attachment[content-type*="project"]'

export default class extends Controller {
  static values = {
    href: String
  }

  rememberSelection() {
    this.selecting = this.hasMeaningfulSelection()
  }

  navigate(event) {
    if (event.target.closest(INTERACTIVE_SELECTOR)) return

    const projectLink = this.projectLinkFrom(event.target)
    if (projectLink) {
      event.preventDefault()
      Turbo.visit(projectLink.href, { frame: "_top" })
      return
    }

    const selecting = this.selecting || this.isSelection()
    this.selecting = false
    if (selecting) return

    const frame = this.element.closest("turbo-frame")?.id
    const options = frame ? { frame } : {}

    Turbo.visit(this.hrefValue, options)
  }

  isSelection() {
    const selection = window.getSelection()
    if (!selection || selection.isCollapsed) return false
    if (selection.toString().length <= 1) return false
    if (!selection.rangeCount) return false

    const range = selection.getRangeAt(0)
    return this.element.contains(range.commonAncestorContainer)
  }

  projectLinkFrom(target) {
    const attachment = target.closest(PROJECT_ATTACHMENT_SELECTOR)
    if (!attachment) return null

    return attachment.querySelector("a[href]")
  }
}
