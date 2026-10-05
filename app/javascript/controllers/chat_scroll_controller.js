import { Controller } from "@hotwired/stimulus"
import { distanceFromBottom, keepScroll, pauseInertiaScroll, scrollToBottom } from "helpers/scroll_helpers"

// Distance from the bottom edge that still counts as "reading the latest".
const PINNED_THRESHOLD = 80

// Upper bound for a follow-the-bottom animation when `scrollend` never fires.
const GLIDE_TIMEOUT = 700

// Generic chat list mounted directly on its scroller (scrollport + list in one),
// opens at the newest bullet, pulls older pages from the top, and follows new
// rows only while the reader is already at the bottom. The composer is a
// sibling flex row, so this element owns all remaining space and scrolling.
export default class extends Controller {
  static targets = ["trigger"]
  static values = { path: String, rootMargin: { type: String, default: "400px" } }

  initialize() {
    this.pinned = true
    this.loading = false
    this.prepending = false
    this.followingCreate = false
  }

  connect() {
    // Deliberately not throttled: a dropped trailing call would leave us
    // believing the reader is still at the bottom after they scrolled away.
    this.boundSettlePinned = () => this.#settlePinned()
    this.boundSubmitStart = (event) => this.#pinOnComposerSubmit(event)
    this.boundSubmitEnd = (event) => this.#clearCreateFollow(event)
    this.boundOptimisticCreate = () => this.#pinOnOptimisticCreate()
    this.boundEndGlide = () => this.#endGlide()
    this.opening = true

    this.element.addEventListener("scroll", this.boundSettlePinned, { passive: true })
    this.element.addEventListener("scrollend", this.boundEndGlide)
    document.addEventListener("turbo:submit-start", this.boundSubmitStart)
    document.addEventListener("turbo:submit-end", this.boundSubmitEnd)
    document.addEventListener("composer:optimistic-create", this.boundOptimisticCreate)
    document.addEventListener("composer-attachment:optimistic-create", this.boundOptimisticCreate)
    this.#followCreatedBullets()

    if (this.#scrollPositionRestorable()) {
      this.opening = false
      this.#restoreScrollPosition()
      this.#settlePinned()
    } else {
      scrollToBottom(this.element)
      this.#followSettlingLayoutWhenOpen()
    }
  }

  disconnect() {
    this.element.removeEventListener("scroll", this.boundSettlePinned)
    this.element.removeEventListener("scrollend", this.boundEndGlide)
    clearTimeout(this.glideTimer)
    clearTimeout(this.followCreateTimer)
    document.removeEventListener("turbo:submit-start", this.boundSubmitStart)
    document.removeEventListener("turbo:submit-end", this.boundSubmitEnd)
    document.removeEventListener("composer:optimistic-create", this.boundOptimisticCreate)
    document.removeEventListener("composer-attachment:optimistic-create", this.boundOptimisticCreate)
    if (this.boundOpenSettled) {
      this.element.removeEventListener("scrollend", this.boundOpenSettled)
    }
    clearTimeout(this.openSettleTimer)
    this.mutationObserver?.disconnect()
    this.triggerObserver?.disconnect()
  }

  triggerTargetConnected(trigger) {
    this.#observeTrigger(trigger)
  }


  preserveScrollPosition() {
    sessionStorage.setItem("scrollPosition", this.element.scrollTop)
  }

  #scrollPositionRestorable() {
    const direction = document.querySelector("html").getAttribute("data-turbo-visit-direction")
    const scrollPosition = sessionStorage.getItem("scrollPosition")
    return direction == "back" && scrollPosition > 0
  }

  #restoreScrollPosition() {
    const scrollPosition = sessionStorage.getItem("scrollPosition")
    this.element.scrollTo({ top: scrollPosition })
  }


  // IntersectionObserver only reports changes, so a trigger that stays on screen
  // after a prepend would go quiet. Re-observing asks for a fresh reading, and
  // the loop ends as soon as the new rows push the trigger out of range.
  #observeTrigger(trigger) {
    this.triggerObserver?.disconnect()
    this.triggerObserver = new IntersectionObserver(
      // The opening scroll must settle first: a trigger visible on a pinned
      // short list would otherwise auto-fetch the whole rail mid-animation.
      ([entry]) => entry.isIntersecting && !this.opening && this.#loadPrevPage(),
      { root: this.element, rootMargin: this.rootMarginValue }
    )
    this.triggerObserver.observe(trigger)
  }

  async #loadPrevPage() {
    if (this.loading) return

    const cursor = this.#oldestRailId
    if (!cursor) return this.#stopLoadingPrevPage()

    this.loading = true

    try {
      const url = new URL(this.pathValue, window.location.origin)
      url.searchParams.set("before", cursor)

      const response = await fetch(url.toString(), {
        headers: { Accept: "text/html" }
      })

      if (response.status === 204) return this.#stopLoadingPrevPage()
      if (!response.ok) return

      this.#prepend(await response.text())
    } finally {
      this.loading = false
    }
  }

  // The flag has to outlive the mutation this prepend triggers, and that
  // callback runs as a microtask — hence the timeout, which fires later.
  #prepend(html) {
    this.prepending = true

    const template = document.createElement("template")
    template.innerHTML = html

    pauseInertiaScroll(this.element)
    keepScroll(this.element, () => {
      const fragment = this.#mergeBoundarySection(template.content)
      // The trigger is the scroller's first child (it owns the pinning auto
      // margin), so older rows slot in right after it.
      if (this.hasTriggerTarget) {
        this.triggerTarget.after(fragment)
      } else {
        this.element.prepend(fragment)
      }
    })
    this.#observeTrigger(this.triggerTarget)

    setTimeout(() => { this.prepending = false })
  }

  // A page can end mid-section (a week or day split across two requests). Its
  // last section then continues the one already on screen, so its rows move
  // there instead of duplicating the heading.
  #mergeBoundarySection(fragment) {
    const incoming = [...fragment.children].filter((child) => child.matches("section[id]")).at(-1)
    const existing = incoming && this.element.querySelector(`section[id="${incoming.id}"]`)
    if (!existing) return fragment

    const rows = [...incoming.children].filter((child) => !child.matches("h2"))
    const anchor = existing.querySelector(":scope > :not(h2)")
    anchor ? anchor.before(...rows) : existing.append(...rows)
    incoming.remove()

    return fragment
  }

  #stopLoadingPrevPage() {
    this.triggerObserver?.disconnect()
    this.triggerObserver = null
    if (this.hasTriggerTarget) this.triggerTarget.remove()
  }

  // Wait for the opening smooth scroll (or a timeout when scrollend never
  // fires — short lists, or browsers without the event) before chasing layout.
  #followSettlingLayoutWhenOpen() {
    const start = () => {
      if (!this.opening) return

      this.opening = false
      clearTimeout(this.openSettleTimer)
      scrollToBottom(this.element)
    }

    this.boundOpenSettled = start
    this.element.addEventListener("scrollend", this.boundOpenSettled, { once: true })
    this.openSettleTimer = setTimeout(start, 500)
  }

  // Only a bullet the composer just created moves the list. Resizes, selection,
  // and other markup inside the scroller leave the reader where they are.
  #followCreatedBullets() {
    this.mutationObserver = new MutationObserver((records) => {
      if (!this.followingCreate || this.prepending || this.opening) return

      const addedBullet = records.some((record) =>
        [...record.addedNodes].some((node) => this.#isBulletNode(node))
      )
      if (!addedBullet) return

      this.followingCreate = false
      clearTimeout(this.followCreateTimer)
      this.#glideToBottom()
    })
    this.mutationObserver.observe(this.element, { childList: true, subtree: true })
  }

  #isBulletNode(node) {
    return node.nodeType === Node.ELEMENT_NODE &&
      (node.matches(".bullet") || node.querySelector(".bullet"))
  }

  // Our own animated scroll fires scroll events from far above the bottom, which
  // would unpin the list mid-flight. The flag mutes them until the glide ends
  // (scrollend, or the timeout where that event is missing).
  #glideToBottom() {
    const reduceMotion = matchMedia("(prefers-reduced-motion: reduce)").matches
    if (reduceMotion) return scrollToBottom(this.element)

    this.gliding = true
    clearTimeout(this.glideTimer)
    this.glideTimer = setTimeout(() => this.#endGlide(), GLIDE_TIMEOUT)
    scrollToBottom(this.element, "smooth")
  }

  #endGlide() {
    if (!this.gliding) return

    this.gliding = false
    clearTimeout(this.glideTimer)
    this.#settlePinned()
  }

  // The reader's own bullet always deserves to be seen, even if they had
  // scrolled up before writing it. The scroll itself waits until that bullet
  // is appended.
  #pinOnComposerSubmit(event) {
    if (!event.target.closest(".composer")) return

    this.#armCreateFollow()
  }

  #pinOnOptimisticCreate() {
    this.#armCreateFollow()
  }

  #armCreateFollow() {
    this.pinned = true
    this.followingCreate = true
    clearTimeout(this.followCreateTimer)
    this.followCreateTimer = setTimeout(() => { this.followingCreate = false }, 10000)
  }

  #clearCreateFollow(event) {
    if (event.detail.success) return
    if (!event.target.closest(".composer")) return

    this.followingCreate = false
    clearTimeout(this.followCreateTimer)
  }

  #settlePinned() {
    if (this.gliding) return

    this.pinned = distanceFromBottom(this.element) <= PINNED_THRESHOLD
  }

  get #oldestRailId() {
    const frame = [...this.element.querySelectorAll("turbo-frame.bullet[id]")].find((el) =>
      /^bullet_\d+$/.test(el.id)
    )
    return frame?.id?.split("_").pop()
  }
}
