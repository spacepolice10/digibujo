import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "nextPageLink" ]
  static values = { rootMargin: String }

  nextPageLinkTargetConnected(link) {
    if (link.dataset.preload == "true") {
      this.#loadNextPage(link)
    } else {
      this.#waitForIntersection(link).then(() => this.#loadNextPage(link))
    }
  }

  async #loadNextPage(link) {
    const html = await this.#fetchNextPageHTML(link.href)
    await this.#nextFrame()
    link.outerHTML = html
  }

  async #fetchNextPageHTML(url) {
    const response = await fetch(url, { headers: { Accept: "text/html" } })
    const html = await response.text()
    const doc = new DOMParser().parseFromString(html, "text/html")
    const container = doc.querySelector(`[data-controller~="${this.identifier}"]`)
    return container ? container.innerHTML.trim() : ""
  }

  #waitForIntersection(element) {
    const rootMargin = this.rootMarginValue || "200px"
    return new Promise(resolve => {
      new IntersectionObserver(([ entry ], observer) => {
        if (!entry.isIntersecting) return
        observer.disconnect()
        resolve()
      }, { rootMargin }).observe(element)
    })
  }

  #nextFrame() {
    return new Promise(resolve => requestAnimationFrame(resolve))
  }

  get nextPageLink() {
    const links = this.nextPageLinkTargets
    return links[links.length - 1]
  }
}
