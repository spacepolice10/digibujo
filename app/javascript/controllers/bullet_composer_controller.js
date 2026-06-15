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

  connect() {
    this.bindBodyEditors()
    this.updateTypeUi()
    if (this.hasPreviewsTarget) {
      this.previewsTarget.hidden = this.previewsTarget.children.length == 0
    }
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
    const upload = new DirectUpload(file, this.directUploadUrlValue, this)
    const preview = this.buildPreview(file)

    upload.create((error, blob) => {
      if (error) {
        preview.remove()
        return
      }

      this.appendSignedId(blob.signed_id)
      preview.dataset.signedId = blob.signed_id
      preview.querySelector("[data-blob-filename]").textContent = file.name
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

  buildPreview(file) {
    const preview = document.createElement("div")
    preview.className = "attachment--preview"
    preview.innerHTML = `
      <span data-blob-filename></span>
      <button type="button" class="button--icon button--tertiary" aria-label="Remove attachment">
        <i class="icon" style="--icon-mask: var(--icon-x)" aria-hidden="true"></i>
      </button>
    `
    preview.querySelector("button").addEventListener("click", () => this.removePreview(preview))
    preview.querySelector("[data-blob-filename]").textContent = file.name
    this.previewsTarget.appendChild(preview)
    this.previewsTarget.hidden = false
    return preview
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

  handleKeydown(event) {
    if (event.isComposing) return
    if (event.key != "Enter") return
    if (this.hasExpandDialogTarget && this.expandDialogTarget.open) return

    event.preventDefault()
    this.element.requestSubmit()
  }

  submitExpand() {
    this.element.requestSubmit()
    if (this.hasExpandDialogTarget) {
      this.expandDialogTarget.close()
    }
  }
}
