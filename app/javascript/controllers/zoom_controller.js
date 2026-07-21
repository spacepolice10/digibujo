import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  zoom(event) {
    const img = event.target.closest("figure.attachment--preview img")
    if (!img) return

    const signedId = this.#signedIdFrom(img.src)
    if (!signedId) return

    Turbo.visit(`/attachments/${encodeURIComponent(signedId)}`)
  }

  #signedIdFrom(src) {
    let pathname
    try {
      pathname = new URL(src, window.location.origin).pathname
    } catch {
      return null
    }

    const parts = pathname.split("/")
    const marker = parts.findIndex((part) =>
      part == "redirect" || part == "proxy" || part == "representations"
    )
    if (marker == -1 || marker + 1 >= parts.length) return null

    return decodeURIComponent(parts[marker + 1])
  }
}
