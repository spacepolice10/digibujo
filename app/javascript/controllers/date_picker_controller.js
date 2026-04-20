import { Controller } from "@hotwired/stimulus"
import { calendarDays } from "helpers/calendar"

export default class extends Controller {
  static targets = ["segment", "segmentPicker", "daysButton", "monthsButton", "yearButton", "hiddenDate", "datePickerText", "datePreview", "daysGrid"]
  static values = {
    segment: { type: String, default: "day" },
    date: String
  }

  connect() {
    if (!this.dateValue) this.renderDaysGrid(new Date())
  }

  segmentValueChanged(value) {
    this.segmentTargets.forEach(el => {
      el.classList.toggle("is-active", el.dataset.segment == value)
    })
    this.segmentPickerTargets.forEach(el => {
      el.classList.toggle("button-secondary--active", el.dataset.datePickerSegmentParam == value)
    })
  }

  dateValueChanged(value) {
    if (!value) return
    const [year, month, day] = value.split("-").map(Number)
    if (month !== this._renderedMonth || year !== this._renderedYear) {
      this.renderDaysGrid(new Date(year, month - 1, 1))
    } else {
      this.daysButtonTargets.forEach(el => {
        el.classList.toggle("button-secondary--active", el.dataset.datePickerValueParam == day)
      })
    }
    this.monthsButtonTargets.forEach(el => {
      el.classList.toggle("button-secondary--active", el.dataset.datePickerValueParam == month)
    })
    this.yearButtonTargets.forEach(el => {
      el.classList.toggle("button-secondary--active", el.dataset.datePickerValueParam == year)
    })
    this.datePreviewTarget.textContent = new Date(year, month - 1, day)
      .toLocaleDateString("en-US", { month: "short", day: "numeric", year: "2-digit" })
  }

  renderDaysGrid(date) {
    this._renderedYear = date.getFullYear()
    this._renderedMonth = date.getMonth() + 1
    const today = new Date()
    const isSameMonth = date.getMonth() === today.getMonth() && date.getFullYear() === today.getFullYear()
    const selectedDay = this.dateValue ? Number(this.dateValue.split("-")[2]) : null
    const nodes = calendarDays(date).map(day => {
      if (day) {
        const el = document.createElement("button")
        el.type = "button"
        el.className = "button-secondary"
        el.dataset.datePickerTarget = "daysButton"
        el.dataset.gridNavigationTarget = "item"
        el.dataset.action = "click->date-picker#selectPart"
        el.dataset.datePickerPartParam = "day"
        el.dataset.datePickerValueParam = day
        el.textContent = day
        if (isSameMonth && day === today.getDate()) el.classList.add("button-secondary--today")
        if (day === selectedDay) el.classList.add("button-secondary--active")
        return el
      } else {
        return document.createElement("div")
      }
    })
    this.daysGridTarget.replaceChildren(...nodes)
  }

  save() {
    if (!this.dateValue) return
    const [year, month, day] = this.dateValue.split("-").map(Number)
    this.hiddenDateTarget.value = this.dateValue
    this.datePickerTextTarget.textContent = new Date(year, month - 1, day)
      .toLocaleDateString("en-US", { month: "short", day: "numeric", year: "2-digit" })
    this.element.querySelector("dialog").close()
  }

  showSegment({ params: { segment } }) {
    this.segmentValue = segment
  }

  selectPart({ params: { part, value } }) {
    const today = new Date()
    const fallback = [
      today.getFullYear(),
      String(today.getMonth() + 1).padStart(2, "0"),
      String(today.getDate()).padStart(2, "0")
    ].join("-")
    const [year, month, day] = (this.dateValue || fallback).split("-")
    const parts = { year, month, day }
    parts[part] = String(value).padStart(part == "year" ? 4 : 2, "0")
    this.dateValue = `${parts.year}-${parts.month}-${parts.day}`
  }
}
