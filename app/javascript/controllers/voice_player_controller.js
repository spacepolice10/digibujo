import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "source", "playButton", "playIcon", "stopIcon", "isPlaying", "progress", "duration" ]
  static values = { duration: Number }

  connect() {
    this.isPlayingValue = false
    this.boundTimeUpdate = this.#timeUpdate.bind(this)
    this.boundFinished = this.#finished.bind(this)

    this.sourceTarget.addEventListener("timeupdate", this.boundTimeUpdate)
    this.sourceTarget.addEventListener("ended", this.boundFinished)
    this.sourceTarget.addEventListener("loadedmetadata", this.boundTimeUpdate)

    this.#timeUpdate()
    this.#updatePlayStatus()
  }

  disconnect() {
    this.sourceTarget.removeEventListener("timeupdate", this.boundTimeUpdate)
    this.sourceTarget.removeEventListener("ended", this.boundFinished)
    this.sourceTarget.removeEventListener("loadedmetadata", this.boundTimeUpdate)
    this.#stop()
  }

  toggle(event) {
    event.preventDefault()
    if (this.sourceTarget.paused) this.#play()
    else this.#stop()
  }

  seek(event) {
    const duration = this.#duration()
    if (duration <= 0) return

    const rect = this.progressTarget.getBoundingClientRect()
    const progress = Math.max(0, Math.min(1, (event.clientX - rect.left) / rect.width))
    this.sourceTarget.currentTime = progress * duration
    this.#timeUpdate()
  }

  progressKeydown(event) {
    if (event.key != "ArrowLeft" && event.key != "ArrowRight") return
    event.preventDefault()

    const duration = this.#duration()
    if (duration <= 0) return

    const step = event.key == "ArrowRight" ? 1 : -1
    this.sourceTarget.currentTime = Math.max(0, Math.min(duration, this.sourceTarget.currentTime + step))
    this.#timeUpdate()
  }

  #play() {
    this.sourceTarget.play()
    this.isPlayingValue = true
    this.#updatePlayStatus()
  }

  #stop() {
    this.sourceTarget.pause()
    this.isPlayingValue = false
    this.#updatePlayStatus()
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

  #timeUpdate() {
    const duration = this.#duration()
    const current = this.sourceTarget.currentTime || 0
    const ratio = duration > 0 ? current / duration : 0

    this.progressTarget.setAttribute("aria-valuenow", Math.floor(current))
    if (this.hasDurationTarget) {
      const remaining = duration > 0 ? Math.max(0, duration - current) : duration
      this.durationTarget.textContent = this.#formatTime(this.isPlayingValue ? remaining : duration)
    }

    const bars = this.progressTarget.querySelectorAll(".voice--wave-bar")
    const filled = Math.round(ratio * bars.length)
    bars.forEach((bar, index) => bar.classList.toggle("is-played", index < filled))
  }

  #finished() {
    this.#stop()
    this.sourceTarget.currentTime = 0
    this.#timeUpdate()
  }

  #updatePlayStatus() {
    this.playIconTarget.hidden = this.isPlayingValue
    this.stopIconTarget.hidden = !this.isPlayingValue
    this.playButtonTarget.setAttribute("aria-label", this.isPlayingValue ? "Stop" : "Play")
    this.#timeUpdate()
  }
}
