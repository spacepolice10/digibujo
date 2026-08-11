import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "recordButton", "stopButton", "discardButton", "playButton", "remaining", "status",
    "preview", "previewContainer", "file", "duration",
    "unsupported", "waveform"
  ]

  static values = {
    durationSeconds: { type: Number, default: 60 },
    manageSubmit: { type: Boolean, default: true },
    // Composer shell: pause while recording, discard only after a take is ready.
    // The standalone voice form keeps Discard available for the whole take.
    shell: { type: Boolean, default: false }
  }

  // Detect MediaRecorder support and lock submit until a take exists.
  connect() {
    this.chunks = []
    this.elapsedSeconds = 0
    this.timerInterval = null
    this.waveformInterval = null
    this.mediaRecorder = null
    this.stream = null
    this.audioContext = null
    this.analyser = null
    this.previewLink = null
    this.doneRecording = false

    this.supported = this.#isSupported()

    if (!this.supported) {
      this.unsupportedTarget.hidden = false
      this.recordButtonTarget.disabled = true
    }

    this.updateSubmitStatus()
  }

  // Tear down mic stream, waveform, and timers when the form leaves the DOM.
  disconnect() {
    this.#stopWaveform()
    this.cleanupStream()
    this.cleanupTimers()
  }

  // Request mic, start MediaRecorder + countdown, show waveform.
  async record(event) {
    event.preventDefault()
    if (!this.#isSupported()) return

    try {
      this.stream = await navigator.mediaDevices.getUserMedia({ audio: true })
    } catch {
      this.updateStatus("Microphone access denied.")
      this.#resetUi()
      this.dispatch("denied")
      return
    }

    this.chunks = []
    this.elapsedSeconds = 0
    this.doneRecording = false
    this.cleanupRecording()
    this.updateRemaining()

    const mimeType = this.#preferredMimeType()
    this.mediaRecorder = new MediaRecorder(this.stream, { mimeType })

    this.mediaRecorder.addEventListener("dataavailable", (recordingEvent) => {
      if (recordingEvent.data.size > 0) this.chunks.push(recordingEvent.data)
    })

    this.mediaRecorder.addEventListener("stop", () => this.#finalizeRecording())
    this.mediaRecorder.start(250)
    this.recordButtonTarget.hidden = true
    this.updateStatus("Recording…")
    this.#createWaveform()
    this.stopButtonTarget.hidden = false

    this.timerInterval = window.setInterval(() => {
      this.elapsedSeconds += 1
      this.updateRemaining()

      if (this.elapsedSeconds >= this.durationSecondsValue) this.stop()
    }, 1000)
  }

  // Stop MediaRecorder; waveform/stream cleanup follows via stop handlers.
  stop(event) {
    event?.preventDefault()
    if (!this.mediaRecorder || this.mediaRecorder.state != "recording") return

    this.cleanupTimers()
    this.#stopWaveform()
    this.mediaRecorder.stop()
    this.cleanupStream()
  }

  togglePlay(event) {
    event?.preventDefault()
    if (!this.hasPreviewTarget) return
    if (this.previewTarget.paused) {
      this.previewTarget.play()
      this.playButtonTarget.hidden = true
      this.playButtonTarget.setAttribute("aria-label", "Play")
      this.playButtonTarget.setAttribute("aria-pressed", "true")
      this.playButtonTarget.querySelector(".playing").hidden = false
      this.playButtonTarget.querySelector(".paused").hidden = true
    } else {
      this.previewTarget.pause()
      this.playButtonTarget.hidden = false
      this.playButtonTarget.setAttribute("aria-label", "Pause")
      this.playButtonTarget.setAttribute("aria-pressed", "false")
      this.playButtonTarget.querySelector(".playing").hidden = true
      this.playButtonTarget.querySelector(".paused").hidden = false
    }
  }

  // Throw away the current take and return to idle UI.
  discard(event) {
    event.preventDefault()
    this.stopButtonTarget.hidden = true
    this.playButtonTarget.hidden = true
    this.recordButtonTarget.hidden = false
    this.discardButtonTarget.hidden = true
    this.reset()
  }

  // After a successful Turbo submit, reset recorder state.
  clearOnSubmit(event) {
    if (!event.detail.success) return

    this.reset()
  }

  // Stop an in-progress take if needed, then reset UI.
  reset() {
    if (this.mediaRecorder?.state == "recording") {
      this.mediaRecorder.addEventListener("stop", () => this.#resetUi(), { once: true })
      this.mediaRecorder.stop()
    } else {
      this.#resetUi()
    }

    this.#stopWaveform()
    this.#waveformItems().forEach((item) => {
      item.classList.remove("is-filled")
      item.setAttribute("height", "2")
      item.setAttribute("y", "15")
    })

    this.cleanupStream()
    this.cleanupTimers()
  }

  // Enable Save only when a finished recording is attached. Composers that own
  // their own submit state opt out and listen for the dispatched event instead.
  updateSubmitStatus() {
    this.dispatch("change", { detail: { ready: this.doneRecording } })
    if (!this.manageSubmitValue) return

    this.element.querySelectorAll('button[type="submit"]').forEach((button) => {
      button.disabled = !this.doneRecording
    })
  }

  // Format remaining countdown into the remaining target.
  updateRemaining() {
    const remaining = Math.max(0, this.durationSecondsValue - this.elapsedSeconds)
    const minutes = Math.floor(remaining / 60)
    const seconds = remaining % 60
    this.remainingTarget.textContent = `${minutes}:${seconds.toString().padStart(2, "0")}`
  }

  // Announce status to assistive tech only — never paint it on screen.
  updateStatus(message) {
    if (!this.hasStatusTarget) return

    this.statusTarget.textContent = message
    this.statusTarget.hidden = message.length == 0
  }

  // Clear file + duration inputs for a fresh take.
  cleanupRecording() {
    this.fileTarget.value = ""
    this.durationTarget.value = ""
  }

  // Revoke the object URL used by the preview <audio>.
  revokePreviewLink() {
    URL.revokeObjectURL(this.previewLink ?? "")
    this.previewLink = null
  }

  // Stop all mic tracks.
  cleanupStream() {
    if (!this.stream) return

    this.stream.getTracks().forEach((track) => track.stop())
    this.stream = null
  }

  // Clear the 1s elapsed / auto-stop interval.
  cleanupTimers() {
    window.clearInterval(this.timerInterval)
    this.timerInterval = null
  }

  // Idle UI: hide preview/waveform controls, clear status, re-enable Record.
  #resetUi() {
    this.chunks = []
    this.elapsedSeconds = 0
    this.doneRecording = false
    this.cleanupRecording()
    this.revokePreviewLink()
    this.#stopWaveform()
    this.previewContainerTarget.hidden = true
    this.recordButtonTarget.hidden = false
    this.recordButtonTarget.disabled = !this.supported
    this.updateStatus("")
    this.updateRemaining()
    this.updateSubmitStatus()
  }

  #isSupported() {
    return typeof MediaRecorder != "undefined" &&
      typeof navigator.mediaDevices?.getUserMedia == "function" &&
      this.#preferredMimeType() != null
  }

  // Build File from chunks, set duration, wire preview playback.
  #finalizeRecording() {
    this.#stopWaveform()

    if (this.chunks.length == 0) {
      this.#resetUi()
      return
    }

    const mimeType = this.#preferredMimeType()
    const blob = new Blob(this.chunks, { type: mimeType })
    const extension = mimeType == "audio/mp4" ? "mp4" : "webm"
    const file = new File([blob], `voice-memo.${extension}`, { type: mimeType })

    const duration = Math.min(this.durationSecondsValue, Math.max(1, Math.ceil(this.elapsedSeconds)))
    this.durationTarget.value = duration

    this.revokePreviewLink()
    this.previewLink = URL.createObjectURL(blob)
    this.previewTarget.src = this.previewLink
    this.previewTarget.load()
    this.#syncPreviewDuration(duration)
    this.previewContainerTarget.hidden = false
    this.stopButtonTarget.hidden = true
    this.playButtonTarget.hidden = false
    this.recordButtonTarget.hidden = true
    this.discardButtonTarget.hidden = false

    this.#appendRecording(file)
  }

  // Put the File into the hidden file input and unlock submit.
  #appendRecording(file) {
    const data = new DataTransfer()
    data.items.add(file)
    this.fileTarget.files = data.files

    this.doneRecording = true
    this.updateStatus("")
    this.updateSubmitStatus()
  }

  // Sync preview player duration value + slider aria after a take.
  #syncPreviewDuration(duration) {
    this.previewTarget.dataset.voicePlayerDurationValue = duration
    this.previewTarget.setAttribute("aria-valuemax", duration)
  }

  // Pick webm or mp4 for MediaRecorder, or null if unsupported.
  #preferredMimeType() {
    if (typeof MediaRecorder == "undefined") return null

    if (MediaRecorder.isTypeSupported("audio/webm")) return "audio/webm"
    if (MediaRecorder.isTypeSupported("audio/mp4")) return "audio/mp4"

    return null
  }

  // SVG rects (.voice--waveform-item) inside the waveform target.
  #waveformItems() {
    return this.waveformTarget.querySelectorAll(".voice--waveform-item")
  }

  // Open AudioContext/analyser on the mic stream and start the bar tick.
  // Progress uses wall-clock time so bars advance many times a second; each bar
  // freezes its height when entered instead of pulsing in place for a full second.
  #createWaveform() {
    this.waveformTarget.hidden = false
    this.recordingStartedAt = performance.now()
    this.waveformBarIndex = -1
    this.audioContext = new AudioContext()
    this.analyser = this.audioContext.createAnalyser()
    this.analyser.fftSize = 256
    this.analyser.smoothingTimeConstant = 0.35
    this.audioContext.createMediaStreamSource(this.stream).connect(this.analyser)
    this.audioContext.resume()

    this.waveformInterval = window.setInterval(() => this.#tickWaveform(), 50)
    this.#tickWaveform()
  }

  // Paint newly reached bars once from the current loudness sample.
  #tickWaveform() {
    if (!this.analyser || this.recordingStartedAt == null) return

    const items = this.#waveformItems()
    if (items.length === 0) return

    const elapsed = Math.min(
      this.durationSecondsValue,
      (performance.now() - this.recordingStartedAt) / 1000
    )
    const index = Math.min(
      items.length - 1,
      Math.floor((items.length * elapsed) / this.durationSecondsValue)
    )

    if (index <= this.waveformBarIndex) return

    const level = this.#sampleLoudness()
    const height = Math.max(2, Math.round(2 + level * 28))
    const y = (32 - height) / 2

    for (let i = this.waveformBarIndex + 1; i <= index; i += 1) {
      const item = items[i]
      item.classList.add("is-filled")
      item.setAttribute("height", height)
      item.setAttribute("y", y)
    }

    this.waveformBarIndex = index
  }

  // RMS amplitude 0..1 from the analyser time-domain buffer, boosted so quiet
  // mics still move the meter.
  #sampleLoudness() {
    const data = new Uint8Array(this.analyser.fftSize)
    this.analyser.getByteTimeDomainData(data)
    let sum = 0
    for (const value of data) {
      const delta = (value - 128) / 128
      sum += delta * delta
    }
    return Math.min(1, Math.sqrt(sum / data.length) * 4.5)
  }

  // Cancel tick, close AudioContext, reset items, hide waveform.
  #stopWaveform() {
    window.clearInterval(this.waveformInterval)
    this.waveformInterval = null
    this.recordingStartedAt = null
    this.waveformBarIndex = -1
    this.audioContext?.close()
    this.audioContext = null
    this.analyser = null

  }
}