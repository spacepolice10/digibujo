import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.onFrameLoad = (event) => {
      if (event.target != this.element) return
      if (!this.element.querySelector(".bullet-form")) return

      requestAnimationFrame(() => this.scrollToFrame())
    }

    this.onKeydown = this.#onKeydown.bind(this)

    this.element.addEventListener("turbo:frame-load", this.onFrameLoad)
    document.addEventListener("keydown", this.onKeydown)
  }

  disconnect() {
    this.element.removeEventListener("turbo:frame-load", this.onFrameLoad)
    document.removeEventListener("keydown", this.onKeydown)
  }

  #onKeydown(event) {
    if (event.key != "Escape") return
    if (event.defaultPrevented) return
    if (document.querySelector("dialog[open]")) return

    const form = this.element.querySelector(".bullet-form")
    if (!form) return
    if (form.dataset.bulletComposerEditingValue == "true") return
    if (!this.element.matches(":focus-within")) return

    const url = form.dataset.composerFramePickerUrl
    if (!url) return

    event.preventDefault()
    this.element.src = url
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
      frame.scrollIntoView({ block: "end", behavior: "smooth" })
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
