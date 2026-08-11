import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "recorder", "recordButton", "stopButton", "discardButton", "playButton", "remaining", "status",
    "preview", "file", "duration", "unsupported", "waveform"
  ]

  static values = {
    durationSeconds: { type: Number, default: 60 }
  }

  connect() {
    this.supported = this.#isSupported()
    this.requestId = 0
    this.previewLink = null
    this.#resetState()

    if (!this.supported) {
      if (this.hasUnsupportedTarget) this.unsupportedTarget.hidden = false
      this.remainingTarget.hidden = true
      this.recordButtonTarget.disabled = true
    }
  }

  disconnect() {
    this.requestId += 1
    this.#stopRecorder()
    this.#cleanupStream()
    this.#cleanupTimers()
    this.#stopWaveform()
    this.#revokePreviewLink()
  }

  async record(event) {
    event?.preventDefault()
    if (!this.supported || this.state != "idle") return

    this.#setState("requesting")
    const requestId = ++this.requestId

    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true })
      if (requestId != this.requestId || this.state != "requesting") {
        stream.getTracks().forEach((track) => track.stop())
        return
      }
      this.stream = stream
    } catch {
      if (requestId != this.requestId) return
      this.#setState("idle")
      this.#updateStatus("Microphone access denied.")
      this.dispatch("denied")
      return
    }

    this.chunks = []
    this.elapsedSeconds = 0
    this.#clearRecording()
    this.#resetWaveform()

    this.mediaRecorder = new MediaRecorder(this.stream, { mimeType: this.#preferredMimeType() })
    this.mediaRecorder.addEventListener("dataavailable", ({ data }) => {
      if (data.size > 0) this.chunks.push(data)
    })
    const recordingId = this.requestId
    this.mediaRecorder.addEventListener("stop", () => {
      if (recordingId == this.requestId && this.state == "recording") this.#finalizeRecording()
    }, { once: true })
    this.mediaRecorder.start(250)

    this.recordingStartedAt = performance.now()
    this.#setState("recording")
    this.#createWaveform()
    this.timerInterval = window.setInterval(() => this.#recordingTick(), 200)
    this.#recordingTick()
  }

  stop(event) {
    event?.preventDefault()
    if (this.state != "recording") return

    this.elapsedSeconds = this.#recordingElapsed()
    this.#cleanupTimers()
    this.#stopWaveform()
    this.#stopRecorder()
    this.#cleanupStream()
  }

  async togglePlay(event) {
    event?.preventDefault()
    if (this.state != "ready" && this.state != "playing") return

    if (this.previewTarget.paused) {
      try {
        await this.previewTarget.play()
      } catch {
        this.#setState("ready")
      }
    } else {
      this.previewTarget.pause()
    }
  }

  seek(event) {
    if (this.state != "ready" && this.state != "playing") return
    const duration = this.#previewDuration()
    const rect = this.waveformTarget.getBoundingClientRect()
    const waveformWidth = rect.width * this.#recordedWaveformRatio()
    if (duration <= 0 || waveformWidth <= 0) return

    const ratio = Math.max(0, Math.min(1, (event.clientX - rect.left) / waveformWidth))
    this.previewTarget.currentTime = ratio * duration
    this.updatePlaybackProgress()
  }

  seekByKeyboard(event) {
    if (!["ArrowLeft", "ArrowRight", "Home", "End"].includes(event.key)) return
    if (this.state != "ready" && this.state != "playing") return
    event.preventDefault()

    const duration = this.#previewDuration()
    if (event.key == "Home") this.previewTarget.currentTime = 0
    if (event.key == "End") this.previewTarget.currentTime = duration
    if (event.key == "ArrowLeft") this.previewTarget.currentTime = Math.max(0, this.previewTarget.currentTime - 1)
    if (event.key == "ArrowRight") this.previewTarget.currentTime = Math.min(duration, this.previewTarget.currentTime + 1)
    this.updatePlaybackProgress()
  }

  discard(event) {
    event?.preventDefault()
    this.restore()
  }

  modeChanged(event) {
    const recording = event.detail.mode == "recorder"
    if (!recording) this.restore()

    this.element.querySelector("select[name='bullet[bulletable_type]']").disabled = recording
    this.element.querySelector("input[name='bullet[bulletable_type]'][value='Voice']").disabled = !recording
    this.element.querySelector("button[type='submit']").disabled = recording
  }

  updatePlaybackProgress() {
    const duration = this.#previewDuration()
    const current = Math.min(duration, this.previewTarget.currentTime || 0)
    const played = duration > 0 ? current / duration : 0
    const allItems = this.#waveformItems()
    const items = this.#recordedWaveformItems()
    const playedCount = Math.round(played * items.length)

    allItems.forEach((item) => item.classList.remove("is-played"))
    items.forEach((item, index) => item.classList.toggle("is-played", index < playedCount))
    this.waveformTarget.setAttribute("aria-valuenow", Math.floor(current))
    this.waveformTarget.setAttribute("aria-valuetext", `${this.#formatTime(current)} of ${this.#formatTime(duration)}`)
    this.#updateRemaining()
  }

  finishPlayback() {
    this.previewTarget.currentTime = 0
    this.#setState("ready")
    this.updatePlaybackProgress()
  }

  syncPlaybackStatus() {
    if (!this.previewTarget.paused && !this.previewTarget.ended) {
      this.#setState("playing")
    } else if (this.state == "playing") {
      this.#setState("ready")
    }
  }

  restore() {
    this.requestId += 1
    this.#stopRecorder()
    this.#cleanupStream()
    this.#cleanupTimers()
    this.#stopWaveform()
    this.#resetState()
  }

  #resetState() {
    this.chunks = []
    this.elapsedSeconds = 0
    this.recordingStartedAt = null
    this.#clearRecording()
    if (this.hasPreviewTarget) this.previewTarget.pause()
    this.#revokePreviewLink()
    if (this.hasPreviewTarget) {
      this.previewTarget.removeAttribute("src")
      this.previewTarget.load()
    }
    this.#resetWaveform()
    this.#updateStatus("")
    this.#setState("idle")
  }

  #setState(state) {
    this.state = state
    this.recorderTarget.dataset.composerRecorderState = state

    this.recordButtonTarget.hidden = state != "idle" && state != "requesting"
    this.recordButtonTarget.disabled = !this.supported || state == "requesting"
    this.stopButtonTarget.hidden = state != "recording"
    this.playButtonTarget.hidden = state != "ready" && state != "playing"
    this.discardButtonTarget.hidden = state != "ready" && state != "playing"

    const playing = state == "playing"
    this.playButtonTarget.setAttribute("aria-label", playing ? "Pause recording" : "Play recording")
    this.playButtonTarget.setAttribute("aria-pressed", playing.toString())
    this.playButtonTarget.querySelector(".playing")?.toggleAttribute("hidden", !playing)
    this.playButtonTarget.querySelector(".paused")?.toggleAttribute("hidden", playing)

    const interactiveWaveform = state == "ready" || state == "playing"
    this.waveformTarget.setAttribute("aria-disabled", (!interactiveWaveform).toString())
    this.waveformTarget.tabIndex = interactiveWaveform ? 0 : -1
    if (state == "requesting") this.#updateStatus("Requesting microphone access…")
    if (state == "recording") this.#updateStatus("Recording…")
    if (state == "ready" || state == "playing") this.#updateStatus("")
    this.#updateRemaining()
    this.#updateSubmitStatus()
  }

  #recordingTick() {
    this.elapsedSeconds = this.#recordingElapsed()
    this.#updateRemaining()
    if (this.elapsedSeconds >= this.durationSecondsValue) this.stop()
  }

  #recordingElapsed() {
    if (this.recordingStartedAt == null) return 0
    return Math.min(this.durationSecondsValue, (performance.now() - this.recordingStartedAt) / 1000)
  }

  #finalizeRecording() {
    this.mediaRecorder = null
    if (this.chunks.length == 0) {
      this.#resetState()
      return
    }

    const mimeType = this.#preferredMimeType()
    const blob = new Blob(this.chunks, { type: mimeType })
    const extension = mimeType == "audio/mp4" ? "mp4" : "webm"
    const file = new File([blob], `voice-memo.${extension}`, { type: mimeType })
    const duration = Math.min(this.durationSecondsValue, Math.max(1, Math.ceil(this.elapsedSeconds)))

    const data = new DataTransfer()
    data.items.add(file)
    this.fileTarget.files = data.files
    this.durationTarget.value = duration

    this.#revokePreviewLink()
    this.previewLink = URL.createObjectURL(blob)
    this.previewTarget.src = this.previewLink
    this.previewTarget.dataset.duration = duration
    this.previewTarget.load()

    this.waveformTarget.setAttribute("aria-valuemax", duration)
    this.#setState("ready")
    this.updatePlaybackProgress()
  }

  #previewDuration() {
    const metadataDuration = this.previewTarget.duration
    if (metadataDuration && isFinite(metadataDuration)) return metadataDuration
    return Number(this.previewTarget.dataset.duration || this.durationTarget.value) || 0
  }

  #updateRemaining() {
    let seconds = this.durationSecondsValue
    if (this.state == "recording") seconds = Math.max(0, this.durationSecondsValue - this.elapsedSeconds)
    if (this.state == "ready" || this.state == "playing") {
      seconds = Math.max(0, this.#previewDuration() - (this.previewTarget.currentTime || 0))
    }
    const rounded = Math.ceil(seconds)
    const minutes = Math.floor(rounded / 60)
    this.remainingTarget.textContent = `${minutes}:${(rounded % 60).toString().padStart(2, "0")}`
  }

  #formatTime(seconds) {
    const rounded = Math.max(0, Math.floor(seconds))
    return `${Math.floor(rounded / 60)}:${(rounded % 60).toString().padStart(2, "0")}`
  }

  #updateSubmitStatus() {
    const ready = this.state == "ready" || this.state == "playing"
    if (this.element.dataset.composerModeValue != "recorder") return
    this.element.querySelector("button[type='submit']").disabled = !ready
  }

  #updateStatus(message) {
    if (!this.hasStatusTarget) return
    this.statusTarget.textContent = message
    this.statusTarget.hidden = message.length == 0
  }

  #clearRecording() {
    this.fileTarget.value = ""
    this.durationTarget.value = ""
  }

  #stopRecorder() {
    if (this.mediaRecorder?.state == "recording") this.mediaRecorder.stop()
  }

  #cleanupStream() {
    this.stream?.getTracks().forEach((track) => track.stop())
    this.stream = null
  }

  #cleanupTimers() {
    window.clearInterval(this.timerInterval)
    this.timerInterval = null
  }

  #revokePreviewLink() {
    if (this.previewLink) URL.revokeObjectURL(this.previewLink)
    this.previewLink = null
  }

  #isSupported() {
    return typeof MediaRecorder != "undefined" &&
      typeof navigator.mediaDevices?.getUserMedia == "function" &&
      this.#preferredMimeType() != null
  }

  #preferredMimeType() {
    if (typeof MediaRecorder == "undefined") return null
    if (MediaRecorder.isTypeSupported("audio/webm")) return "audio/webm"
    if (MediaRecorder.isTypeSupported("audio/mp4")) return "audio/mp4"
    return null
  }

  #waveformItems() {
    return this.waveformTarget.querySelectorAll(".voice--waveform-item")
  }

  #recordedWaveformItems() {
    return [...this.#waveformItems()].filter((item) => item.classList.contains("is-filled"))
  }

  #recordedWaveformRatio() {
    const items = this.#waveformItems()
    return items.length > 0 ? this.#recordedWaveformItems().length / items.length : 0
  }

  #createWaveform() {
    this.waveformBarIndex = -1
    const AudioContextClass = window.AudioContext || window.webkitAudioContext
    if (AudioContextClass) {
      this.audioContext = new AudioContextClass()
      this.analyser = this.audioContext.createAnalyser()
      this.analyser.fftSize = 256
      this.analyser.smoothingTimeConstant = 0.35
      this.audioContext.createMediaStreamSource(this.stream).connect(this.analyser)
      this.audioContext.resume()
    }
    this.waveformInterval = window.setInterval(() => this.#tickWaveform(), 50)
    this.#tickWaveform()
  }

  #tickWaveform() {
    const items = this.#waveformItems()
    if (items.length == 0) return
    const index = Math.min(items.length - 1, Math.floor(items.length * this.#recordingElapsed() / this.durationSecondsValue))
    if (index <= this.waveformBarIndex) return

    const height = Math.max(2, Math.round(2 + this.#sampleLoudness() * 28))
    for (let i = this.waveformBarIndex + 1; i <= index; i += 1) {
      items[i].classList.add("is-filled")
      items[i].setAttribute("height", height)
      items[i].setAttribute("y", (32 - height) / 2)
    }
    this.waveformBarIndex = index
  }

  #sampleLoudness() {
    if (!this.analyser) return 0.1
    const data = new Uint8Array(this.analyser.fftSize)
    this.analyser.getByteTimeDomainData(data)
    const sum = data.reduce((total, value) => total + ((value - 128) / 128) ** 2, 0)
    return Math.min(1, Math.sqrt(sum / data.length) * 4.5)
  }

  #stopWaveform() {
    window.clearInterval(this.waveformInterval)
    this.waveformInterval = null
    this.audioContext?.close()
    this.audioContext = null
    this.analyser = null
  }

  #resetWaveform() {
    this.#waveformItems().forEach((item) => {
      item.classList.remove("is-filled", "is-played")
      item.setAttribute("height", "2")
      item.setAttribute("y", "15")
    })
    this.waveformTarget.setAttribute("aria-valuenow", "0")
  }
}
