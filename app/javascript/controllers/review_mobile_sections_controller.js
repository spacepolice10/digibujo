import { Controller } from "@hotwired/stimulus"

// Scroll the mobile snap track to the To review section on connect.
export default class extends Controller {
  static targets = ["track", "review"]

  connect() {
    this.#scrollToReview()
  }

  #scrollToReview() {
    if (!this.hasTrackTarget || !this.hasReviewTarget) return

    const scroll = () => {
      this.reviewTarget.scrollIntoView({ inline: "start", block: "nearest", behavior: "auto" })
    }

    // Wait a frame so layout/snap metrics are ready.
    requestAnimationFrame(scroll)
  }
}
