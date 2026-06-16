import { Controller } from "@hotwired/stimulus"
import { DirectUpload } from "@rails/activestorage"

const TYPE_MARKERS = {
  Task: { icon: "square", styles: "bullet--task-marker" },
  Note: { icon: "line-dashed", styles: "bullet--note-marker" },
  Event: { icon: "circle", styles: "bullet--event-marker" },
}

export default class extends Controller {
  static targets = [
    "fileInput",
    "previews",
    "attachmentsField",
    "typeSelect",
    "noteOptions",
    "marker",
    "markerIcon",
    "expandDialog",
  ]

  static values = {
    directUploadUrl: String,
  }

  bindBodyEditors() {
    this.element.querySelectorAll('lexxy-editor[preset="inline"]').forEach((editor) => {
      if (editor.dataset.fileAcceptBound) return

      editor.dataset.fileAcceptBound = "true"
      editor.addEventListener("lexxy:file-accept", this.interceptFile.bind(this))
    })
  }

  interceptFile(event) {
    event.preventDefault()
    this.uploadFile(event.detail.file)
  }

  pickFile() {
    this.fileInputTarget.click()
  }

  fileInputChanged(event) {
    for (const file of event.target.files) {
      this.uploadFile(file)
    }
    event.target.value = ""
  }

  uploadFile(file) {
    const preview = this.makePreview(file)
    const delegate = {
      directUploadWillStoreFileWithXhr: (xhr) => {
        xhr.upload.addEventListener("progress", () => {})
      }
    }

    const upload = new DirectUpload(file, this.directUploadUrlValue, delegate)

    upload.create((error, blob) => {
      if (error) {
        this.changeStatus(preview, "failed")
        return
      }

      this.changeStatus(preview, "finished")
      this.appendSignedId(blob.signed_id)
      preview.dataset.signedId = blob.signed_id
    })
  }

  appendSignedId(signedId) {
    const input = document.createElement("input")
    input.type = "hidden"
    input.name = "bullet[attachments][]"
    input.value = signedId
    input.dataset.bulletComposerSignedId = signedId
    this.attachmentsFieldTarget.appendChild(input)
  }

  makePreview(file) {
    const preview = document.createElement("div")
    preview.className = "attachment--preview"
    preview.dataset.attachmentStatus = "pending"
    preview.innerHTML = `
      <i class="icon attachment--status-icon icon--spin" style="--icon-mask: var(--icon-spinner)"></i>
      <span data-blob-filename>${file.name}</span>
      <button type="button" class="button--icon button--tertiary" aria-label="Remove attachment">
        <i class="icon" style="--icon-mask: var(--icon-x)" aria-hidden="true"></i>
      </button>
    `
    preview.querySelector("button").addEventListener("click", () => this.removePreview(preview))
    this.previewsTarget.appendChild(preview)
    this.previewsTarget.hidden = false
    return preview
  }

  changeStatus(preview, status) {
    preview.dataset.attachmentStatus = status
    const icon = preview.querySelector(".attachment--status-icon")
    icon.classList.toggle("icon--spin", status == "pending")

    const map = { pending: "spinner", finished: "circle-check", failed: "x" }
    icon.style.setProperty("--icon-mask", `var(--icon-${map[status]})`)
  }

  removePreview(preview) {
    const signedId = preview.dataset.signedId
    if (signedId) {
      this.attachmentsFieldTarget
        .querySelectorAll(`input[data-bullet-composer-signed-id="${signedId}"]`)
        .forEach((input) => input.remove())
    }
    preview.remove()
    this.previewsTarget.hidden = this.previewsTarget.children.length == 0
  }

  typeChanged() {
    this.updateTypeUi()
  }

  updateTypeUi() {
    if (!this.hasTypeSelectTarget) return

    const type = this.typeSelectTarget.value
    const marker = TYPE_MARKERS[type] || TYPE_MARKERS.Task

    if (this.hasMarkerTarget) {
      this.markerTarget.className = `bullet--marker ${marker.styles}`
    }
    if (this.hasMarkerIconTarget) {
      this.markerIconTarget.style.setProperty("--icon-mask", `var(--icon-${marker.icon})`)
    }
    if (this.hasNoteOptionsTarget) {
      this.noteOptionsTarget.hidden = type != "Note"
    }
  }

  connect() {
    this.bindBodyEditors()
    this.updateTypeUi()
    if (this.hasPreviewsTarget) {
      this.previewsTarget.hidden = this.previewsTarget.children.length == 0
    }
  }

  clearOnSubmit(event) {
    if (!event.detail.success) return

    this.reset()
  }

  reset() {
    this.element.querySelectorAll("trix-editor").forEach((el) => {
      if (el.editor) el.editor.setContent("")
    })

    this.previewsTarget.querySelectorAll(".attachment--preview").forEach((preview) => {
      this.removePreview(preview)
    })

    if (this.hasTypeSelectTarget) {
      this.typeSelectTarget.value = "Task"
      this.updateTypeUi()
    }

    if (this.hasExpandDialogTarget) {
      this.expandDialogTarget.close()
    }

    const inlineEditor = this.element.querySelector('trix-editor[preset="inline"]')
    if (inlineEditor?.editor) {
      inlineEditor.editor.setSelectedRange([0, 0])
      inlineEditor.focus()
    }
  }

  handleKeydown(event) {
    if (event.isComposing) return
    if (event.key != "Enter") return
    if (this.hasExpandDialogTarget && this.expandDialogTarget.open) return

    event.preventDefault()
    this.element.requestSubmit()
  }

  submitExpand() {
    const expandEditor = this.element.querySelector('trix-editor[preset="expand"]')
    if (expandEditor?.editor) {
      expandEditor.editor.setContent("")
    }
    this.element.requestSubmit()
    if (this.hasExpandDialogTarget) {
      this.expandDialogTarget.close()
    }
  }
}
