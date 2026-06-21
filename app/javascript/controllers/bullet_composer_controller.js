import { Controller } from "@hotwired/stimulus"
import { DirectUpload } from "@rails/activestorage"

export default class extends Controller {
  static targets = [
    "fileInput",
    "previews",
    "attachmentsField",
    "typeSelect",
    "typeLabel",
    "actionsSelect",
    "noteOptions",
    "indentField",
    "expandDialog",
    "richBodyPreview",
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

  actionChanged() {
    if (!this.hasActionsSelectTarget) return

    const action = this.actionsSelectTarget.value
    this.actionsSelectTarget.value = ""

    if (action == "attachment") {
      this.pickFile()
    } else if (action == "expand" && this.hasExpandDialogTarget) {
      this.expandDialogTarget.showModal()
    }
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
    this.typeSelectTarget.dataset.type = type
    this.typeSelectTarget.querySelectorAll(".bullet-form-type-select-marker-item").forEach((marker) => {
      marker.hidden = marker.dataset.type != type
    })
    if (this.hasTypeLabelTarget) {
      this.typeLabelTarget.querySelectorAll("[data-type]").forEach((label) => {
        label.hidden = label.dataset.type != type
      })
    }
    if (this.hasNoteOptionsTarget) {
      this.noteOptionsTarget.hidden = type != "Note"
    }
  }

  cycleType(direction) {
    if (!this.hasTypeSelectTarget) return

    const options = Array.from(this.typeSelectTarget.options).filter((option) => option.value)
    if (options.length == 0) return

    const currentIndex = options.findIndex((option) => option.value == this.typeSelectTarget.value)
    const nextIndex = (currentIndex + direction + options.length) % options.length

    this.typeSelectTarget.value = options[nextIndex].value
    this.typeSelectTarget.dispatchEvent(new Event("change", { bubbles: true }))
  }

  selectType(event) {
    if (!this.hasTypeSelectTarget) return

    const type = event.currentTarget.dataset.type
    if (!type) return

    this.typeSelectTarget.value = type
    this.typeSelectTarget.dispatchEvent(new Event("change", { bubbles: true }))
  }

  updateIndentUi() {
    const indented = this.hasIndentFieldTarget && this.indentFieldTarget.checked
    this.element.classList.toggle("bullet-form--indented", indented)
  }

  connect() {
    this.bindBodyEditors()
    this.updateTypeUi()
    this.updateIndentUi()
    if (this.hasPreviewsTarget) {
      this.previewsTarget.hidden = this.previewsTarget.children.length == 0
    }
    if (this.hasRichBodyPreviewTarget) {
      this.syncRichBodyPreviewVisibility()
    }
  }

  clearOnSubmit(event) {
    if (!event.detail.success) return

    this.clearForNextEntry()
  }

  clearForNextEntry() {
    const inlineEditor = this.element.querySelector('lexxy-editor[preset="inline"]')
    if (inlineEditor) inlineEditor.value = ""

    const expandEditor = this.element.querySelector('lexxy-editor[preset="expand"]')
    if (expandEditor) expandEditor.value = ""

    if (this.hasPreviewsTarget) {
      this.previewsTarget.querySelectorAll(".attachment--preview").forEach((preview) => {
        this.removePreview(preview)
      })
    }

    if (this.hasExpandDialogTarget) {
      this.expandDialogTarget.close()
    }

    if (this.hasRichBodyPreviewTarget) {
      this.clearRichBodyPreview()
    }

    inlineEditor?.focus()
  }

  handleKeydown(event) {
    if (event.isComposing) return

    if (event.shiftKey && event.key == ">") {
      if (!this.hasIndentFieldTarget) return

      event.preventDefault()
      this.indentFieldTarget.checked = !this.indentFieldTarget.checked
      this.updateIndentUi()
      return
    }

    if (event.ctrlKey && event.shiftKey && event.key == "Tab") {
      if (this.hasExpandDialogTarget && this.expandDialogTarget.open) return
      if (!this.hasTypeSelectTarget) return

      event.preventDefault()
      this.cycleType(-1)
      return
    }

    if (event.key != "Enter") return
    if (this.hasExpandDialogTarget && this.expandDialogTarget.open) return

    event.preventDefault()
    this.element.requestSubmit()
  }

  saveExpand() {
    const expandEditor = this.element.querySelector('lexxy-editor[preset="expand"]')
    if (expandEditor) {
      this.syncRichBodyPreview(expandEditor.value)
    }

    if (this.hasExpandDialogTarget) {
      this.expandDialogTarget.close()
    }

    this.element.querySelector('lexxy-editor[preset="inline"]')?.focus()
  }

  syncRichBodyPreview(html) {
    if (!this.hasRichBodyPreviewTarget) return

    const content = this.richBodyPreviewTarget.querySelector(".bullet-form-rich-body-preview-content")
    if (!content) return

    if (this.richBodyContentPresent(html)) {
      content.innerHTML = html
      this.richBodyPreviewTarget.hidden = false
    } else {
      this.clearRichBodyPreview()
    }
  }

  syncRichBodyPreviewVisibility() {
    const content = this.richBodyPreviewTarget.querySelector(".bullet-form-rich-body-preview-content")
    if (!content) return

    this.richBodyPreviewTarget.hidden = !this.richBodyContentPresent(content.innerHTML)
  }

  clearRichBodyPreview() {
    if (!this.hasRichBodyPreviewTarget) return

    const content = this.richBodyPreviewTarget.querySelector(".bullet-form-rich-body-preview-content")
    if (content) content.innerHTML = ""
    this.richBodyPreviewTarget.hidden = true
  }

  richBodyContentPresent(html) {
    if (!html || !html.trim()) return false

    const doc = new DOMParser().parseFromString(html, "text/html")
    return doc.body.textContent.trim().length > 0
  }
}
