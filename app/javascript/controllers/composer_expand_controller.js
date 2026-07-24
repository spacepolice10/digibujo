import { Controller } from "@hotwired/stimulus"

const VT_CLASS = "is-composer-expanding"

// Marks which create control shares `bullet-composer` with the page shell.
// Also flags <html data-composer-vt> so root page content stays hidden while
// the shell morphs (avoids editor-on-editor).
export default class extends Controller {
  connect() {
    this.onClick = (event) => this.#onClick(event)
    this.onBeforeRender = (event) => this.#onBeforeRender(event)
    this.onLoad = () => this.#onLoad()
    this.waitingForVt = false

    document.addEventListener("turbo:click", this.onClick)
    document.addEventListener("turbo:before-render", this.onBeforeRender)
    document.addEventListener("turbo:load", this.onLoad)
  }

  disconnect() {
    document.removeEventListener("turbo:click", this.onClick)
    document.removeEventListener("turbo:before-render", this.onBeforeRender)
    document.removeEventListener("turbo:load", this.onLoad)
  }

  #onClick(event) {
    if (this.#reducedMotion) return

    const link = event.target.closest("[data-composer-expand]")
    if (!link) return

    this.#clear(document)
    link.classList.add(VT_CLASS)
    this.#arm()
  }

  #onBeforeRender(event) {
    if (this.#reducedMotion) return

    const leaving = document.querySelector(".bullets-form--page")
    const entering = event.detail.newBody.querySelector(".bullets-form--page")
    if (!leaving && !entering) return

    this.#arm()

    if (!leaving) return

    const type = leaving.dataset.bulletType
    if (!type) return

    const newBody = event.detail.newBody
    this.#clear(newBody)

    const button = newBody.querySelector(
      `[data-composer-expand][data-bullet-type="${CSS.escape(type)}"]`
    )
    if (button) button.classList.add(VT_CLASS)
  }

  #onLoad() {
    this.#clear(document)
    if (!this.waitingForVt) this.#unarm()
  }

  #arm() {
    document.documentElement.dataset.composerVt = ""
    if (this.waitingForVt) return

    this.waitingForVt = true

    const onReveal = (event) => {
      window.removeEventListener("pagereveal", onReveal)
      if (event.viewTransition) {
        event.viewTransition.finished.finally(() => this.#unarm())
      } else {
        this.#unarm()
      }
    }

    window.addEventListener("pagereveal", onReveal)
  }

  #unarm() {
    this.waitingForVt = false
    delete document.documentElement.dataset.composerVt
  }

  #clear(root) {
    root.querySelectorAll(`[data-composer-expand].${VT_CLASS}`).forEach((el) => {
      el.classList.remove(VT_CLASS)
    })
  }

  get #reducedMotion() {
    return matchMedia("(prefers-reduced-motion: reduce)").matches
  }
}
