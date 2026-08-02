import { Controller } from "@hotwired/stimulus"

const VARIANTS = { date: ["Task", "Event"], unplanned: ["Note"] }
const VT = "monthlylog-composer"
// After the last scroll tick — covers browsers without scrollend.
const SCROLL_SETTLE_MS = 140

// Shared Lexxy composer: Create bullet docks it (VT morph); Esc parks (desktop).
// Mobile mounts into the date dock on connect; IO remembers the winning dock
// while swiping and expands from the destination chip once scroll settles.
// Context is applied before the swap; we only await updateCallbackDone so
// Note↔Task chrome does not wait on the full morph.
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
    clearTimeout(this.scrollFallback)
    this.spread?.removeEventListener("scrollend", this.boundFlushDock)
    this.spread?.removeEventListener("scroll", this.boundScrollFallback)
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
    if (!this.#composer || !dock) return Promise.resolve()

    // Context before the morph — type/allowlist/placeholder must match the
    // destination as soon as the shell lands, not after the VT finishes.
    this.#apply(this.#context(side))

    return this.#move(dock, pane, { trigger, animate }).then(() => {
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
    if (composer.parentElement === dock) {
      this.#mark(pane)
      return
    }

    const swap = () => { dock.append(composer); this.#mark(pane) }
    // Expand from the destination Create-bullet chip (tap or settled swipe).
    const chip = trigger instanceof HTMLElement
      ? trigger
      : dock.querySelector(".monthlylog--create-bullet")

    if (!animate || this.#reduce || !document.startViewTransition) {
      swap()
      if (!this.#reduce) this.#pulse(composer)
      return
    }

    const fromChip = chip instanceof HTMLElement
    ;(fromChip ? chip : composer).style.viewTransitionName = VT
    try {
      const transition = document.startViewTransition(() => {
        if (fromChip) chip.style.viewTransitionName = ""
        swap()
        composer.style.viewTransitionName = VT
      })
      // Context already applied; unlock callers after DOM swap, but keep the
      // morph running. Hold #flushPendingDock via this.morphing until finished
      // so a second swipe cannot cancel the animation mid-flight.
      await transition.updateCallbackDone
      this.morphing = transition.finished.finally(() => {
        this.morphing = null
        composer.style.viewTransitionName = ""
        if (chip instanceof HTMLElement) chip.style.viewTransitionName = ""
      })
    } catch {
      this.morphing = null
      composer.style.viewTransitionName = ""
      if (chip instanceof HTMLElement) chip.style.viewTransitionName = ""
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

    this.spread = root
    this.pendingSide = null
    this.dockMoving = false

    this.io = new IntersectionObserver((entries) => {
      const best = entries
        .filter((e) => e.isIntersecting)
        .sort((a, b) => b.intersectionRatio - a.intersectionRatio)[0]
      if (!best || best.intersectionRatio < 0.55) return

      const side = best.target === this.unplannedDockTarget ? "unplanned" : "date"
      const dock = side === "date" ? this.dateDockTarget : this.unplannedDockTarget
      if (this.#composer?.parentElement === dock) {
        this.pendingSide = null
        return
      }
      this.pendingSide = side
    }, { root, threshold: [0.35, 0.55, 0.75] })

    this.boundFlushDock = () => this.#flushPendingDock()
    this.boundScrollFallback = () => {
      clearTimeout(this.scrollFallback)
      this.scrollFallback = setTimeout(this.boundFlushDock, SCROLL_SETTLE_MS)
    }

    root.addEventListener("scrollend", this.boundFlushDock, { passive: true })
    root.addEventListener("scroll", this.boundScrollFallback, { passive: true })

    this.io.observe(this.dateDockTarget)
    this.io.observe(this.unplannedDockTarget)
  }

  async #flushPendingDock() {
    if (this.dockMoving || this.pendingSide == null) return

    const side = this.pendingSide
    const dock = side === "date" ? this.dateDockTarget : this.unplannedDockTarget
    if (this.#composer?.parentElement === dock) {
      this.pendingSide = null
      return
    }

    this.pendingSide = null
    this.dockMoving = true
    try {
      await this.#show(side, { animate: true, focus: false })
      if (this.morphing) await this.morphing
    } finally {
      this.dockMoving = false
      if (this.pendingSide) queueMicrotask(() => this.#flushPendingDock())
    }
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
