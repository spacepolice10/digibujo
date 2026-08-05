import { Controller } from "@hotwired/stimulus"
import { distanceFromBottom, keepScroll, pauseInertiaScroll, scrollToBottom } from "helpers/scroll_helpers"

// Distance from the bottom edge that still counts as "reading the latest".
const PINNED_THRESHOLD = 80

// Generic chat list: owns its merged scroller (scrollport + list in one),
// opens at the newest bullet, pulls older pages from the top, and follows new
// rows only while the reader is already at the bottom. Scroller padding (CSS)
// clears the fixed composer dock.
export default class extends Controller {
  static targets = ["scroller", "trigger"]
  static values = { path: String, rootMargin: { type: String, default: "400px" } }

  initialize() {
    this.pinned = true
    this.loading = false
    this.prepending = false
  }

  connect() {
    // Deliberately not throttled: a dropped trailing call would leave us
    // believing the reader is still at the bottom after they scrolled away.
    this.boundSettlePinned = () => this.#settlePinned()
    this.opening = true

    this.scrollerTarget.addEventListener("scroll", this.boundSettlePinned, { passive: true })

    if (this.#scrollPositionRestorable()) {
      this.#restoreScrollPosition()
    } else {
      scrollToBottom(this.scrollerTarget)
      this.#followSettlingLayoutWhenOpen()
    }
  }

  disconnect() {

    this.scrollerTarget.removeEventListener("scroll", this.boundSettlePinned)
    if (this.boundOpenSettled) {
      this.scrollerTarget.removeEventListener("scrollend", this.boundOpenSettled)
    }
    clearTimeout(this.openSettleTimer)
    this.sizeObserver?.disconnect()
    this.triggerObserver?.disconnect()
  }

  triggerTargetConnected(trigger) {
    this.#observeTrigger(trigger)
  }


  preserveScrollPosition() {
    sessionStorage.setItem("scrollPosition", this.scrollerTarget.scrollTop)
  }

  #scrollPositionRestorable() {
    const direction = document.querySelector("html").getAttribute("data-turbo-visit-direction")
    const scrollPosition = sessionStorage.getItem("scrollPosition")
    return direction == "back" && scrollPosition > 0
  }

  #restoreScrollPosition() {
    const scrollPosition = sessionStorage.getItem("scrollPosition")
    this.scrollerTarget.scrollTo({ top: scrollPosition })
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
      { root: this.scrollerTarget, rootMargin: this.rootMarginValue }
    )
    this.triggerObserver.observe(trigger)
  }

  async #loadPrevPage() {
    if (this.loading) return

    const cursor = this.#oldestRailId
    if (!cursor) return this.#stopLoadingPrevPage()

    this.loading = true

    try {
      const response = await fetch(`${this.pathValue}?before=${encodeURIComponent(cursor)}`, {
        headers: { Accept: "text/html" }
      })

      if (response.status === 204) return this.#stopLoadingPrevPage()
      if (!response.ok) return

      this.#prepend(await response.text())
    } finally {
      this.loading = false
    }
  }

  // The flag has to outlive the ResizeObserver pass this prepend triggers, and
  // that pass runs after animation frame callbacks — hence the timeout.
  #prepend(html) {
    this.prepending = true

    pauseInertiaScroll(this.scrollerTarget)
    keepScroll(this.scrollerTarget, () => {
      // The trigger is the scroller's first child (it owns the pinning auto
      // margin), so older rows slot in right after it.
      if (this.hasTriggerTarget) {
        this.triggerTarget.insertAdjacentHTML("afterend", html)
      } else {
        this.scrollerTarget.insertAdjacentHTML("afterbegin", html)
      }
    })
    this.#observeTrigger(this.triggerTarget)

    setTimeout(() => { this.prepending = false })
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
      scrollToBottom(this.scrollerTarget)
      this.#followSettlingLayout()
    }

    this.boundOpenSettled = start
    this.scrollerTarget.addEventListener("scrollend", this.boundOpenSettled, { once: true })
    this.openSettleTimer = setTimeout(start, 500)
  }

  // Web fonts, rich text and the editor all settle after the first paint and
  // leave the list a few pixels taller than when we jumped to the bottom. It
  // also catches the row the composer just created landing a beat after
  // turbo:submit-end, when the composer's own #scrollToLatest already ran.
  #followSettlingLayout() {
    if (typeof ResizeObserver === "undefined") return

    this.sizeObserver = new ResizeObserver(() => {
      if (this.prepending || !this.pinned) return

      scrollToBottom(this.scrollerTarget)
    })
    this.sizeObserver.observe(this.scrollerTarget)
  }

  #settlePinned() {
    this.pinned = distanceFromBottom(this.scrollerTarget) <= PINNED_THRESHOLD
  }

  get #oldestRailId() {
    return this.scrollerTarget.querySelector('[id^="bullet_"]')?.id?.split("_").pop()
  }
}
