import { Controller } from "@hotwired/stimulus"
import { DirectUpload } from "@rails/activestorage"

export default class extends Controller {
  static targets = [
    "recordButton", "stopButton", "discardButton", "timer", "status",
    "preview", "previewContainer", "signedIdInput", "durationInput",
    "unsupported"
  ]

  static values = {
    maxDuration: { type: Number, default: 60 },
    directUploadUrl: String
  }

  connect() {
    this.chunks = []
    this.elapsedSeconds = 0
    this.timerInterval = null
    this.mediaRecorder = null
    this.stream = null
    this.previewUrl = null
    this.ready = false
    this.uploading = false

    this.boundReset = this.reset.bind(this)
    this.boundUpdateSubmitState = this.updateSubmitState.bind(this)
    this.editor = this.element.querySelector('lexxy-editor[preset="inline"]')

    this.supported = typeof MediaRecorder != "undefined" &&
      typeof navigator.mediaDevices?.getUserMedia == "function" &&
      this.#preferredMimeType() != null

    if (!this.supported) {
      this.unsupportedTarget.hidden = false
      this.recordButtonTarget.disabled = true
    }

    this.element.addEventListener("composer:rebind", this.boundReset)
    this.element.addEventListener("input", this.boundUpdateSubmitState)
    this.element.addEventListener("change", this.boundUpdateSubmitState)
    this.editor?.addEventListener("lexxy:change", this.boundUpdateSubmitState)

    this.updateSubmitState()
  }

  disconnect() {
    this.element.removeEventListener("composer:rebind", this.boundReset)
    this.element.removeEventListener("input", this.boundUpdateSubmitState)
    this.element.removeEventListener("change", this.boundUpdateSubmitState)
    this.editor?.removeEventListener("lexxy:change", this.boundUpdateSubmitState)
    this.cleanupStream()
    this.clearTimer()
  }

  async start(event) {
    event.preventDefault()
    if (!this.supported || this.uploading) return

    try {
      this.stream = await navigator.mediaDevices.getUserMedia({ audio: true })
    } catch {
      this.setStatus("Microphone access denied.")
      return
    }

    this.chunks = []
    this.elapsedSeconds = 0
    this.ready = false
    this.clearSignedId()
    this.updateTimerDisplay()

    const mimeType = this.#preferredMimeType()
    this.mediaRecorder = new MediaRecorder(this.stream, { mimeType })

    this.mediaRecorder.addEventListener("dataavailable", (recordingEvent) => {
      if (recordingEvent.data.size > 0) this.chunks.push(recordingEvent.data)
    })

    this.mediaRecorder.addEventListener("stop", () => this.#finalizeRecording())

    this.mediaRecorder.start(250)
    this.recordButtonTarget.hidden = true
    this.stopButtonTarget.hidden = false
    this.discardButtonTarget.hidden = false
    this.previewContainerTarget.hidden = true
    this.setStatus("Recording…")

    this.timerInterval = window.setInterval(() => {
      this.elapsedSeconds += 1
      this.updateTimerDisplay()

      if (this.elapsedSeconds >= this.maxDurationValue) this.stop()
    }, 1000)
  }

  stop(event) {
    event?.preventDefault()
    if (!this.mediaRecorder || this.mediaRecorder.state != "recording") return

    this.clearTimer()
    this.mediaRecorder.stop()
    this.cleanupStream()
    this.stopButtonTarget.hidden = true
  }

  discard(event) {
    event.preventDefault()
    this.reset()
  }

  clearOnSubmit(event) {
    if (!event.detail.success) return
    if (event.detail.formSubmission?.submitter?.name != "another") return

    this.reset()
  }

  reset() {
    if (this.mediaRecorder?.state == "recording") {
      this.mediaRecorder.addEventListener("stop", () => this.#resetUi(), { once: true })
      this.mediaRecorder.stop()
    } else {
      this.#resetUi()
    }

    this.cleanupStream()
    this.clearTimer()
  }

  updateSubmitState() {
    const captionPresent = this.#captionPresent()
    const canSubmit = this.ready && captionPresent && !this.uploading

    this.element.querySelectorAll('button[type="submit"]').forEach((button) => {
      button.disabled = !canSubmit
    })
  }

  #resetUi() {
    this.chunks = []
    this.elapsedSeconds = 0
    this.ready = false
    this.uploading = false
    this.clearSignedId()
    this.revokePreviewUrl()
    this.#resetPreviewPlayer()
    this.previewContainerTarget.hidden = true
    this.recordButtonTarget.hidden = false
    this.stopButtonTarget.hidden = true
    this.discardButtonTarget.hidden = true
    this.recordButtonTarget.disabled = !this.supported
    this.setStatus("")
    this.updateTimerDisplay()
    this.updateSubmitState()
  }

  #finalizeRecording() {
    if (this.chunks.length == 0) {
      this.#resetUi()
      return
    }

    const mimeType = this.#preferredMimeType()
    const blob = new Blob(this.chunks, { type: mimeType })
    const extension = mimeType == "audio/mp4" ? "mp4" : "webm"
    const file = new File([blob], `voice-memo.${extension}`, { type: mimeType })

    const duration = Math.min(this.maxDurationValue, Math.max(1, Math.ceil(this.elapsedSeconds)))
    this.durationInputTarget.value = duration

    this.revokePreviewUrl()
    this.previewUrl = URL.createObjectURL(blob)
    this.previewTarget.src = this.previewUrl
    this.previewTarget.load()
    this.#syncPreviewDuration(duration)
    this.previewContainerTarget.hidden = false

    this.upload(file)
  }

  upload(file) {
    this.uploading = true
    this.setStatus("Uploading…")
    this.updateSubmitState()

    const upload = new DirectUpload(file, this.directUploadUrlValue, this)

    upload.create((error, blob) => {
      this.uploading = false

      if (error) {
        this.setStatus("Upload failed.")
        this.ready = false
        this.updateSubmitState()
        return
      }

      this.signedIdInputTarget.value = blob.signed_id
      this.ready = true
      this.setStatus("Ready to save.")
      this.updateSubmitState()
    })
  }

  #previewPlayer() {
    return this.previewContainerTarget.querySelector(".voice--playback")
  }

  #syncPreviewDuration(duration) {
    const player = this.#previewPlayer()
    if (!player) return

    player.dataset.voicePlayerDurationValue = duration

    const progress = player.querySelector('[role="slider"]')
    if (progress) progress.setAttribute("aria-valuemax", duration)
  }

  #resetPreviewPlayer() {
    if (!this.hasPreviewTarget) return

    this.previewTarget.pause()
    this.previewTarget.removeAttribute("src")
    this.previewTarget.load()
    this.#syncPreviewDuration(0)
  }

  #preferredMimeType() {
    if (typeof MediaRecorder == "undefined") return null

    if (MediaRecorder.isTypeSupported("audio/webm")) return "audio/webm"
    if (MediaRecorder.isTypeSupported("audio/mp4")) return "audio/mp4"

    return null
  }

  #captionPresent() {
    const editor = this.element.querySelector('lexxy-editor[preset="inline"]')
    if (!editor) return false

    const value = editor.value?.trim?.() || editor.textContent?.trim?.() || ""
    return value.length > 0
  }

  updateTimerDisplay() {
    const remaining = Math.max(0, this.maxDurationValue - this.elapsedSeconds)
    const minutes = Math.floor(remaining / 60)
    const seconds = remaining % 60
    this.timerTarget.textContent = `${minutes}:${seconds.toString().padStart(2, "0")}`
  }

  setStatus(message) {
    if (!this.hasStatusTarget) return

    this.statusTarget.textContent = message
    this.statusTarget.hidden = message.length == 0
  }

  clearSignedId() {
    this.signedIdInputTarget.value = ""
    this.durationInputTarget.value = ""
  }

  revokePreviewUrl() {
    if (!this.previewUrl) return

    URL.revokeObjectURL(this.previewUrl)
    this.previewUrl = null
  }

  cleanupStream() {
    if (!this.stream) return

    this.stream.getTracks().forEach((track) => track.stop())
    this.stream = null
  }

  clearTimer() {
    if (!this.timerInterval) return

    window.clearInterval(this.timerInterval)
    this.timerInterval = null
  }
}
