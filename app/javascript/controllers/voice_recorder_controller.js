import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "recordButton", "stopButton", "discardButton", "remaining", "status",
    "preview", "previewContainer", "file", "duration",
    "unsupported", "waveform"
  ]

  static values = {
    durationSeconds: { type: Number, default: 60 }
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

    this.supported = typeof MediaRecorder != "undefined" &&
      typeof navigator.mediaDevices?.getUserMedia == "function" &&
      this.#preferredMimeType() != null

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
    if (!this.supported) return

    try {
      this.stream = await navigator.mediaDevices.getUserMedia({ audio: true })
    } catch {
      this.updateStatus("Microphone access denied.")
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
    this.discardButtonTarget.hidden = false
    this.previewContainerTarget.hidden = true
    this.updateStatus("Recording…")
    this.#createWaveform()

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

  // Throw away the current take and return to idle UI.
  discard(event) {
    event.preventDefault()
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
    this.cleanupStream()
    this.cleanupTimers()
  }

  // Enable Save only when a finished recording is attached.
  updateSubmitStatus() {
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

  // Show or hide the status line message.
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
    this.#resetPreviewPlayer()
    this.#stopWaveform()
    this.previewContainerTarget.hidden = true
    this.recordButtonTarget.hidden = false
    this.discardButtonTarget.hidden = true
    this.recordButtonTarget.disabled = !this.supported
    this.updateStatus("")
    this.updateRemaining()
    this.updateSubmitStatus()
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

    this.#appendRecording(file)
  }

  // Put the File into the hidden file input and unlock submit.
  #appendRecording(file) {
    const data = new DataTransfer()
    data.items.add(file)
    this.fileTarget.files = data.files

    this.doneRecording = true
    this.updateStatus("Ready to save.")
    this.updateSubmitStatus()
  }

  // Find the voice-player root inside the preview container.
  #previewPlayer() {
    return this.previewContainerTarget.querySelector(".voice--playback")
  }

  // Sync preview player duration value + slider aria after a take.
  #syncPreviewDuration(duration) {
    const player = this.#previewPlayer()
    if (!player) return

    player.dataset.voicePlayerDurationValue = duration

    const progress = player.querySelector('[role="slider"]')
    if (progress) progress.setAttribute("aria-valuemax", duration)
  }

  // Pause/clear preview <audio> and zero its duration UI.
  #resetPreviewPlayer() {
    this.previewTarget?.pause()
    this.previewTarget?.removeAttribute("src")
    this.previewTarget?.load()
    this.#syncPreviewDuration(0)
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

  // Open AudioContext/analyser on the mic stream and start the 150ms bar tick.
  #createWaveform() {
    this.waveformTarget.hidden = false
    this.audioContext = new AudioContext()
    this.analyser = this.audioContext.createAnalyser()
    this.analyser.fftSize = 256
    this.audioContext.createMediaStreamSource(this.stream).connect(this.analyser)
    this.audioContext.resume()

    this.waveformInterval = window.setInterval(() => this.#tickWaveform(), 150)
    this.#tickWaveform()
  }

  // Advance filled items from elapsedSeconds; set current item height from loudness.
  #tickWaveform() {
    if (!this.analyser) return

    const items = this.#waveformItems()
    const level = this.#sampleLoudness()
    const filled = Math.floor(items.length * this.elapsedSeconds / this.durationSecondsValue)
    const h = Math.max(2, Math.round(level * 28))

    items.forEach((item, i) => {
      const active = i <= filled
      item.classList.toggle("is-filled", active)
      if (i == filled) {
        item.setAttribute("height", h)
        item.setAttribute("y", (32 - h) / 2)
      } else if (!active) {
        item.setAttribute("height", "2")
        item.setAttribute("y", "15")
      }
    })
  }

  // Peak amplitude 0..1 from the analyser time-domain buffer.
  #sampleLoudness() {
    const data = new Uint8Array(this.analyser.fftSize)
    this.analyser.getByteTimeDomainData(data)
    let peak = 0
    for (const v of data) peak = Math.max(peak, Math.abs(v - 128))
    return Math.min(1, peak / 64)
  }

  // Cancel tick, close AudioContext, reset items, hide waveform.
  #stopWaveform() {
    window.clearInterval(this.waveformInterval)
    this.waveformInterval = null
    this.audioContext?.close()
    this.audioContext = null
    this.analyser = null

    if (!this.hasWaveformTarget) return

    this.#waveformItems().forEach((item) => {
      item.classList.remove("is-filled")
      item.setAttribute("height", "2")
      item.setAttribute("y", "15")
    })
    this.waveformTarget.hidden = true
  }
}
