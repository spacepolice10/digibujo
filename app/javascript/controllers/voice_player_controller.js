import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "source", "playButton", "playIcon", "stopIcon", "progress", "duration" ]
  static values = { duration: Number }

  connect() {
    this.updateProgress()
    this.syncPlaybackStatus()
  }

  disconnect() {
    this.sourceTarget.pause()
  }

  toggle(event) {
    event.preventDefault()
    if (this.sourceTarget.paused) this.#play()
    else this.sourceTarget.pause()
  }

  seek(event) {
    const duration = this.#duration()
    if (duration <= 0) return

    const rect = this.progressTarget.getBoundingClientRect()
    if (rect.width <= 0) return
    const progress = Math.max(0, Math.min(1, (event.clientX - rect.left) / rect.width))
    this.sourceTarget.currentTime = progress * duration
    this.updateProgress()
  }

  progressKeydown(event) {
    if (event.key != "ArrowLeft" && event.key != "ArrowRight") return
    event.preventDefault()

    const duration = this.#duration()
    if (duration <= 0) return

    const step = event.key == "ArrowRight" ? 1 : -1
    this.sourceTarget.currentTime = Math.max(0, Math.min(duration, this.sourceTarget.currentTime + step))
    this.updateProgress()
  }

  finish() {
    this.sourceTarget.currentTime = 0
    this.updateProgress()
    this.syncPlaybackStatus()
  }

  syncPlaybackStatus() {
    const playing = !this.sourceTarget.paused && !this.sourceTarget.ended
    this.playIconTarget.hidden = playing
    this.stopIconTarget.hidden = !playing
    this.playButtonTarget.setAttribute("aria-label", playing ? "Pause" : "Play")
    this.playButtonTarget.setAttribute("aria-pressed", playing.toString())
  }

  updateProgress() {
    const duration = this.#duration()
    const current = this.sourceTarget.currentTime || 0
    const ratio = duration > 0 ? Math.max(0, Math.min(1, current / duration)) : 0

    this.progressTarget.setAttribute("aria-valuenow", Math.floor(current))
    this.progressTarget.setAttribute("aria-valuetext", `${this.#formatTime(current)} of ${this.#formatTime(duration)}`)
    if (this.hasDurationTarget) {
      const remaining = duration > 0 ? Math.max(0, duration - current) : duration
      this.durationTarget.textContent = this.#formatTime(remaining)
    }

    const bars = this.progressTarget.querySelectorAll(".voice--wave-bar")
    const filled = Math.round(ratio * bars.length)
    bars.forEach((bar, index) => bar.classList.toggle("is-played", index < filled))
  }

  async #play() {
    try {
      await this.sourceTarget.play()
    } catch {
      this.syncPlaybackStatus()
    }
  }

  #duration() {
    if (this.durationValue > 0) return this.durationValue
    const { duration } = this.sourceTarget
    if (duration && isFinite(duration)) return duration
    return 0
  }

  #formatTime(seconds) {
    const _seconds = Math.max(0, Math.floor(seconds))
    const minutes = Math.floor(_seconds / 60)
    return `${minutes}:${(_seconds % 60).toString().padStart(2, "0")}`
  }

}
