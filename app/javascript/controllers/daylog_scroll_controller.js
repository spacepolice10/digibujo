import { Controller } from "@hotwired/stimulus"
import { distanceFromBottom, keepScroll, pauseInertiaScroll, scrollToBottom } from "helpers/scroll_helpers"

// Distance from the bottom edge that still counts as "reading the latest".
const PINNED_THRESHOLD = 80

// Chat shell for the daylog: the list owns its own scrollport, opens at the
// newest bullet, pulls older pages in from the top, and follows new rows only
// while the reader is already at the bottom. The page is always full-viewport;
// scroller padding (CSS) clears the fixed composer dock.
export default class extends Controller {
  static targets = ["scroller", "list", "trigger"]
  static values = { url: String, rootMargin: { type: String, default: "300px" } }

  initialize() {
    this.pinned = true
    this.loading = false
    this.prepending = false
  }

  connect() {
    // Deliberately not throttled: a dropped trailing call would leave us
    // believing the reader is still at the bottom after they scrolled away.
    this.boundTrackPin = () => this.#trackPin()

    this.scrollerTarget.addEventListener("scroll", this.boundTrackPin, { passive: true })

    scrollToBottom(this.scrollerTarget)
    this.#followAppendedRows()
    this.#followSettlingLayout()
  }

  disconnect() {
    this.scrollerTarget.removeEventListener("scroll", this.boundTrackPin)
    this.rowObserver?.disconnect()
    this.sizeObserver?.disconnect()
    this.triggerObserver?.disconnect()
  }

  triggerTargetConnected(trigger) {
    this.#observeTrigger(trigger)
  }

  // IntersectionObserver only reports changes, so a trigger that stays on screen
  // after a prepend would go quiet. Re-observing asks for a fresh reading, and
  // the loop ends as soon as the new rows push the trigger out of range.
  #observeTrigger(trigger) {
    this.triggerObserver?.disconnect()
    this.triggerObserver = new IntersectionObserver(
      ([entry]) => entry.isIntersecting && this.#loadOlderPage(),
      { root: this.scrollerTarget, rootMargin: this.rootMarginValue }
    )
    this.triggerObserver.observe(trigger)
  }

  async #loadOlderPage() {
    if (this.loading) return

    const cursor = this.#oldestRowId
    if (!cursor) return this.#stopLoadingOlder()

    this.loading = true

    try {
      const response = await fetch(`${this.urlValue}?before=${encodeURIComponent(cursor)}`, {
        headers: { Accept: "text/html" }
      })

      if (response.status === 204) return this.#stopLoadingOlder()
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
    keepScroll(this.scrollerTarget, () => this.listTarget.insertAdjacentHTML("afterbegin", html))
    this.#observeTrigger(this.triggerTarget)

    setTimeout(() => { this.prepending = false })
  }

  #stopLoadingOlder() {
    this.triggerObserver?.disconnect()
    this.triggerObserver = null
    if (this.hasTriggerTarget) this.triggerTarget.remove()
  }

  // Rows arrive by Turbo Stream, so watch the list rather than the composer.
  #followAppendedRows() {
    this.rowObserver = new MutationObserver(() => {
      if (this.prepending || !this.pinned) return

      scrollToBottom(this.scrollerTarget, "smooth")
    })
    this.rowObserver.observe(this.listTarget, { childList: true })
  }

  // Web fonts, rich text and the editor all settle after the first paint and
  // leave the list a few pixels taller than when we jumped to the bottom.
  #followSettlingLayout() {
    if (typeof ResizeObserver === "undefined") return

    this.sizeObserver = new ResizeObserver(() => {
      if (this.prepending || !this.pinned) return

      scrollToBottom(this.scrollerTarget)
    })
    this.sizeObserver.observe(this.listTarget)
  }

  #trackPin() {
    this.pinned = distanceFromBottom(this.scrollerTarget) <= PINNED_THRESHOLD
  }

  get #oldestRowId() {
    return this.listTarget.firstElementChild?.id?.split("_").pop()
  }
}
