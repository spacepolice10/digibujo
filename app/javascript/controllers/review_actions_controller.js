import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    bulletId: String,
    collectsPickerUrl: { type: String, default: "/bullets/collect/new" },
    collectFrameId: { type: String, default: "review_collect_picker_frame" }
  }

  openCollectPicker() {
    const frame = document.getElementById(this.collectFrameIdValue)
    if (!frame) return

    const url = new URL(this.collectsPickerUrlValue, window.location.origin)
    url.searchParams.set("bullet_ids", this.bulletIdValue)
    url.searchParams.set("frame_id", this.collectFrameIdValue)
    const nextSrc = `${url.pathname}${url.search}`

    if (frame.src != nextSrc) frame.src = nextSrc
    if (frame.hasAttribute("popover") && !frame.matches(":popover-open")) frame.showPopover()
  }
}
