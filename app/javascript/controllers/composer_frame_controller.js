import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.onFrameLoad = (event) => {
      if (event.target != this.element) return
      if (!this.element.querySelector(".bullet-form")) return

      requestAnimationFrame(() => this.scrollToFrame())
    }

    this.element.addEventListener("turbo:frame-load", this.onFrameLoad)
  }

  disconnect() {
    this.element.removeEventListener("turbo:frame-load", this.onFrameLoad)
  }

  scrollToFrame() {
    const frame = this.element
    const container = this.scrollParent(frame)

    if (container) {
      const frameTop =
        frame.getBoundingClientRect().top -
        container.getBoundingClientRect().top +
        container.scrollTop
      const padding = parseFloat(getComputedStyle(container).paddingBottom) || 0
      const targetScroll =
        frameTop - container.clientHeight + frame.offsetHeight + padding
      const maxScroll = container.scrollHeight - container.clientHeight

      container.scrollTo({
        top: Math.max(0, Math.min(maxScroll, targetScroll)),
        behavior: "smooth",
      })
    } else {
      frame.scrollIntoView({ block: "nearest", behavior: "smooth" })
    }

    const focusTarget = frame.querySelector(
      "lexxy-editor, trix-editor, input:not([type=hidden]), textarea",
    )
    focusTarget?.focus?.()
  }

  scrollParent(element) {
    let node = element.parentElement

    while (node) {
      const { overflowY } = getComputedStyle(node)

      if (/(auto|scroll)/.test(overflowY) && node.scrollHeight > node.clientHeight) {
        return node
      }

      node = node.parentElement
    }

    return null
  }
}
