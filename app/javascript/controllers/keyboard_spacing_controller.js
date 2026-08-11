import { Controller } from "@hotwired/stimulus"

// Tracks the on-screen keyboard via visualViewport and exposes it as CSS
// variables + a state class on the composer element. Self-contained on
// purpose — it only reads viewport/focus state and writes layout hints — so
// it stacks onto the composer element instead of living in composer_controller.
//
//   data-controller="chat-composer keyboard-spacing voice-recorder"
//
// With interactive-widget=resizes-visual the layout viewport / 100dvh stay
// full while the visual viewport shrinks under the keyboard, so we lift the
// dock with a bottom inset (and pad the chat list) instead of crushing the
// scroller. All state reads and writes happen in one rAF batch so the dock,
// tabbar and padder move together with no jumps.
export default class extends Controller {
  connect() {
    this.restingHeight = window.innerHeight
    this.padder = document.querySelector(".chat--padder")
    this.frame = null
    this.lastKey = ""
    this.boundBurst = () => this.#schedule()

    this.#viewport?.addEventListener("resize", this.boundBurst)
    this.#viewport?.addEventListener("scroll", this.boundBurst)
    this.#sync()
  }

  disconnect() {
    if (this.frame != null) cancelAnimationFrame(this.frame)
    this.#viewport?.removeEventListener("resize", this.boundBurst)
    this.#viewport?.removeEventListener("scroll", this.boundBurst)
    this.element.classList.remove("composer--keyboard-open")
    this.element.style.removeProperty("--composer-keyboard-spacing")
  }

  // Coalesce the visual-viewport resize/scroll bursts onto one frame.
  #schedule() {
    if (this.frame != null) return
    this.frame = requestAnimationFrame(() => {
      this.frame = null
      this.#sync()
    })
  }

  #sync() {
    const viewport = this.#viewport
    if (!viewport) return

    const focused = this.element.contains(document.activeElement)
    // Retake the resting baseline whenever we're not focused, so the fallback
    // below only ever measures the keyboard's own change in innerHeight.
    if (!focused) this.restingHeight = window.innerHeight

    // Pinch-zoom shrinks the visual viewport without a keyboard; leave the
    // dock in its current keyboard state (the baseline refresh above ran).
    if (Math.abs((viewport.scale ?? 1) - 1) > 0.01) return

    // keyboard height = layout viewport (innerHeight) minus the visible area.
    const spacing = Math.max(0, Math.round(window.innerHeight - viewport.height))
    // Fallback for browsers that resize the layout viewport instead: spacing
    // stays ~0, but innerHeight drops while focused.
    const resizeDelta = Math.max(0, Math.round(this.restingHeight - window.innerHeight))
    const open = spacing > 0 || (focused && resizeDelta > 50)
    const padder = open ? window.outerHeight - viewport.height - spacing : 0

    this.#apply({ padder, spacing, open })
  }

  // One batch write so the dock, tabbar and padder move together; skip when
  // nothing changed (panning and pinch-zoom fire bursts without a keyboard).
  #apply(state) {
    const key = `${state.padder}:${state.spacing}:${state.open}`
    if (key === this.lastKey) return
    this.lastKey = key

    this.padder?.style.setProperty("--chat-padder-height", `${state.padder}px`)
    this.element.style.setProperty("--composer-keyboard-spacing", `${state.spacing}px`)
    this.element.classList.toggle("composer--keyboard-open", state.open)
  }

  get #viewport() {
    return window.visualViewport
  }
}