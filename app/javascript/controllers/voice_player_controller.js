import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "audio", "playButton", "playIcon", "pauseIcon", "progress", "progressFill" ]
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
    this.#updatePlayState()
  }

  disconnect() {
    this.audioTarget.removeEventListener("timeupdate", this.boundTimeUpdate)
    this.audioTarget.removeEventListener("ended", this.boundEnded)
    this.audioTarget.removeEventListener("loadedmetadata", this.boundTimeUpdate)
    document.removeEventListener("voice-player:play", this.boundOnOtherPlay)
    this.#pause()
  }

  toggle(event) {
    event.preventDefault()
    if (this.audioTarget.paused) this.#play()
    else this.#pause()
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
    this.#updatePlayState()
  }

  #pause() {
    this.audioTarget.pause()
    this.playing = false
    this.#updatePlayState()
  }

  #onOtherPlay(event) {
    if (event.detail.controller != this && !this.audioTarget.paused) this.#pause()
  }

  #duration() {
    if (this.durationValue > 0) return this.durationValue
    const { duration } = this.audioTarget
    if (duration && isFinite(duration)) return duration
    return 0
  }

  #timeUpdate() {
    const duration = this.#duration()
    const percent = duration > 0 ? (this.audioTarget.currentTime / duration) * 100 : 0
    this.progressFillTarget.style.width = `${percent}%`
    this.progressTarget.setAttribute("aria-valuenow", Math.floor(this.audioTarget.currentTime))
  }

  #ended() {
    this.#pause()
    this.audioTarget.currentTime = 0
    this.#timeUpdate()
  }

  #updatePlayState() {
    this.playIconTarget.hidden = this.playing
    this.pauseIconTarget.hidden = !this.playing
    this.playButtonTarget.setAttribute("aria-label", this.playing ? "Pause" : "Play")
  }
}
