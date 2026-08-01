import { Controller } from "@hotwired/stimulus"

const VARIANTS = { date: ["Task", "Event"], unplanned: ["Note"] }
const VT = "monthlylog-composer"

// Shared Lexxy composer: Create bullet docks it (VT morph); Esc parks (desktop).
// Mobile mounts into the date dock on connect; IO moves it while snapping.
export default class extends Controller {
  static values = { bucketId: String, unplannedComposerId: String }
  static targets = ["datePane", "unplannedPane", "dateDock", "unplannedDock", "park"]

  connect() {
    if (!this.#mobile) return
    this.#show("date", { animate: false, focus: false })
    this.#watchDocks()
  }

  disconnect() {
    this.io?.disconnect()
  }

  dateFrameLoaded(event) {
    const frame = event.target
    if (frame.id !== "monthlylog_date") return
    if (this.#composer?.parentElement !== this.dateDockTarget) return
    this.#apply(this.#context("date", frame.dataset.popsOn))
  }

  openDate(event) {
    event?.preventDefault?.()
    this.#show("date", { trigger: event?.currentTarget })
  }

  openUnplanned(event) {
    event?.preventDefault?.()
    this.#show("unplanned", { trigger: event?.currentTarget })
  }

  close(event) {
    if (this.#mobile || !this.#open) return
    event?.preventDefault()
    this.#move(this.parkTarget, null)
  }

  #show(side, { trigger, animate = true, focus = true } = {}) {
    const dock = side === "date" ? this.dateDockTarget : this.unplannedDockTarget
    const pane = side === "date" ? this.datePaneTarget : this.unplannedPaneTarget
    if (!this.#composer || !dock) return

    this.#move(dock, pane, { trigger, animate }).then(() => {
      this.#apply(this.#context(side))
      if (focus) {
        requestAnimationFrame(() => this.#composer.querySelector("lexxy-editor")?.focus?.())
      }
    })
  }

  #context(side, iso = this.#iso) {
    if (side === "unplanned") {
      return { popsOn: null, variants: VARIANTS.unplanned, composerId: this.unplannedComposerIdValue }
    }
    return {
      popsOn: iso,
      variants: VARIANTS.date,
      composerId: `date_${iso}_bullets_composer`
    }
  }

  #apply(ctx) {
    this.application
      .getControllerForElementAndIdentifier(this.#composer, "chat-composer")
      ?.changeContext({ bucketId: this.bucketIdValue, ...ctx })
  }

  async #move(dock, pane, { trigger, animate = true } = {}) {
    const composer = this.#composer
    if (composer.parentElement === dock) return this.#mark(pane)

    const swap = () => { dock.append(composer); this.#mark(pane) }

    if (!animate || this.#reduce || !document.startViewTransition) {
      swap()
      if (!this.#reduce) this.#pulse(composer)
      return
    }

    const fromBtn = trigger instanceof HTMLElement && !this.#open
    ;(fromBtn ? trigger : composer).style.viewTransitionName = VT
    try {
      await document.startViewTransition(() => {
        if (fromBtn) trigger.style.viewTransitionName = ""
        swap()
        composer.style.viewTransitionName = VT
      }).finished
    } finally {
      composer.style.viewTransitionName = ""
      if (trigger instanceof HTMLElement) trigger.style.viewTransitionName = ""
    }
  }

  #pulse(el) {
    el.classList.remove("is-entering")
    void el.offsetWidth
    el.classList.add("is-entering")
    el.addEventListener("animationend", () => el.classList.remove("is-entering"), { once: true })
  }

  #mark(pane) {
    for (const el of [...this.datePaneTargets, ...this.unplannedPaneTargets]) {
      el.classList.toggle("is-composing", el === pane)
    }
  }

  #watchDocks() {
    const root = this.element.querySelector(".monthlylog--spread-sections")
    if (!root || !window.IntersectionObserver) return

    this.io = new IntersectionObserver((entries) => {
      const best = entries
        .filter((e) => e.isIntersecting)
        .sort((a, b) => b.intersectionRatio - a.intersectionRatio)[0]
      if (!best || best.intersectionRatio < 0.55) return
      if (this.#composer?.parentElement === best.target) return
      this.#show(best.target === this.unplannedDockTarget ? "unplanned" : "date", {
        animate: false,
        focus: false
      })
    }, { root, threshold: [0.35, 0.55, 0.75] })

    this.io.observe(this.dateDockTarget)
    this.io.observe(this.unplannedDockTarget)
  }

  get #composer() { return this.element.querySelector("turbo-frame.composer") }
  get #open() { return this.#composer?.parentElement !== this.parkTarget }
  get #mobile() { return this.element.classList.contains("monthlylog--page-mobile") }
  get #reduce() { return matchMedia("(prefers-reduced-motion: reduce)").matches }
  get #iso() {
    return document.getElementById("monthlylog_date")?.dataset?.popsOn
      || this.element.dataset.monthlylogComposerInitialDate
  }
}
