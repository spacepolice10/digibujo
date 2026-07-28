import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "audio", "playButton", "playIcon", "stopIcon", "progress", "duration" ]
  static values = { duration: Number }

  connect() {
    this.playing = false
    this.boundTimeUpdate = this.#timeUpdate.bind(this)
    this.boundEnded = this.#ended.bind(this)
    this.boundOnOtherPlay = this.#onOtherPlay.bind(this)

    this.audioTarget.addEventListener("timeupdate", this.boundTimeUpdate)
    this.audioTarget.addEventListener("ended", this.boundEnded)
    this.audioTarget.addEventListener("loadedmetadata", this.boundTimeUpdate)
    document.addEventListener("voice-player:play", this.boundOnOtherPlay)

    this.#timeUpdate()
    this.#updatePlayStatus()
  }

  disconnect() {
    this.audioTarget.removeEventListener("timeupdate", this.boundTimeUpdate)
    this.audioTarget.removeEventListener("ended", this.boundEnded)
    this.audioTarget.removeEventListener("loadedmetadata", this.boundTimeUpdate)
    document.removeEventListener("voice-player:play", this.boundOnOtherPlay)
    this.#stop()
  }

  toggle(event) {
    event.preventDefault()
    if (this.audioTarget.paused) this.#play()
    else this.#stop()
  }

  seek(event) {
    const duration = this.#duration()
    if (duration <= 0) return

    const rect = this.progressTarget.getBoundingClientRect()
    const ratio = Math.max(0, Math.min(1, (event.clientX - rect.left) / rect.width))
    this.audioTarget.currentTime = ratio * duration
    this.#timeUpdate()
  }

  progressKeydown(event) {
    if (event.key != "ArrowLeft" && event.key != "ArrowRight") return
    event.preventDefault()

    const duration = this.#duration()
    if (duration <= 0) return

    const step = event.key == "ArrowRight" ? 1 : -1
    this.audioTarget.currentTime = Math.max(0, Math.min(duration, this.audioTarget.currentTime + step))
    this.#timeUpdate()
  }

  #play() {
    document.dispatchEvent(new CustomEvent("voice-player:play", { detail: { controller: this } }))
    this.audioTarget.play()
    this.playing = true
    this.#updatePlayStatus()
  }

  #stop() {
    this.audioTarget.pause()
    this.playing = false
    this.#updatePlayStatus()
  }

  #onOtherPlay(event) {
    if (event.detail.controller != this && !this.audioTarget.paused) this.#stop()
  }

  #duration() {
    if (this.durationValue > 0) return this.durationValue
    const { duration } = this.audioTarget
    if (duration && isFinite(duration)) return duration
    return 0
  }

  #formatTime(totalSeconds) {
    const seconds = Math.max(0, Math.floor(totalSeconds))
    const minutes = Math.floor(seconds / 60)
    return `${minutes}:${(seconds % 60).toString().padStart(2, "0")}`
  }

  #timeUpdate() {
    const duration = this.#duration()
    const current = this.audioTarget.currentTime || 0
    const ratio = duration > 0 ? current / duration : 0

    this.progressTarget.setAttribute("aria-valuenow", Math.floor(current))
    if (this.hasDurationTarget) {
      const remaining = duration > 0 ? Math.max(0, duration - current) : duration
      this.durationTarget.textContent = this.#formatTime(this.playing ? remaining : duration)
    }

    const bars = this.progressTarget.querySelectorAll(".voice--wave-bar")
    const filled = Math.round(ratio * bars.length)
    bars.forEach((bar, index) => bar.classList.toggle("is-played", index < filled))
  }

  #ended() {
    this.#stop()
    this.audioTarget.currentTime = 0
    this.#timeUpdate()
  }

  #updatePlayStatus() {
    if (!this.hasPlayIconTarget || !this.hasStopIconTarget) return

    this.playIconTarget.hidden = this.playing
    this.stopIconTarget.hidden = !this.playing
    this.playButtonTarget.setAttribute("aria-label", this.playing ? "Stop" : "Play")
    this.#timeUpdate()
  }
}
