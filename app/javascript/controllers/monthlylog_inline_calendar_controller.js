import { Controller } from "@hotwired/stimulus"

const CELL = ".monthlylog--date-cell-inline"

// Mobile inline calendar stays outside the date turbo-frame, so is-selected
// would stick on the first paint. Move the accent on click; frame-load only
// confirms when it matches the date we asked for (stale loads used to snap
// the chip back to today).
export default class extends Controller {
  connect() {
    this.desiredDate = this.#selected?.dataset.monthlylogDate || null
    this.boundSelect = (event) => this.#select(event.currentTarget)
    this.boundFrameLoaded = (event) => this.#syncFromFrame(event.target)

    for (const cell of this.#cells) {
      cell.addEventListener("click", this.boundSelect)
    }

    this.dateFrame?.addEventListener("turbo:frame-load", this.boundFrameLoaded)

    requestAnimationFrame(() => this.#scrollTo(this.#selected || this.#current))
  }

  disconnect() {
    for (const cell of this.#cells) {
      cell.removeEventListener("click", this.boundSelect)
    }
    this.dateFrame?.removeEventListener("turbo:frame-load", this.boundFrameLoaded)
  }

  #select(cell) {
    if (!(cell instanceof HTMLElement)) return

    const iso = cell.dataset.monthlylogDate
    if (iso) this.desiredDate = iso

    if (cell.classList.contains("is-selected")) return

    this.#selected?.classList.remove("is-selected")
    cell.classList.add("is-selected")
    this.#scrollTo(cell)
  }

  #syncFromFrame(frame) {
    if (frame?.id !== "monthlylog_date") return

    const iso = frame.dataset.popsOn
    if (!iso) return
    // Drop superseded responses (e.g. the initial src=today finishing after a
    // newer day click).
    if (this.desiredDate && this.desiredDate !== iso) return

    this.desiredDate = iso
    const cell = this.#cells.find((el) => el.dataset.monthlylogDate === iso)
    if (cell) this.#select(cell)
  }

  #scrollTo(cell) {
    cell?.scrollIntoView({ inline: "center", block: "nearest", behavior: "smooth" })
  }

  get #cells() {
    return [...this.element.querySelectorAll(CELL)]
  }

  get #selected() {
    return this.element.querySelector(`${CELL}.is-selected`)
  }

  get #current() {
    return this.element.querySelector(`${CELL}.is-current`)
  }

  get dateFrame() {
    return document.getElementById("monthlylog_date")
  }
}
