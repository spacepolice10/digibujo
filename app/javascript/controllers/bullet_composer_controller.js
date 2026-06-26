import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "fileInput",
    "typeSelect",
    "typeLabel",
    "actionsSelect",
    "typeFields",
  ]

  static values = {
    editorUrl: String,
    editing: Boolean,
    actiontextPreset: { type: String, default: "inline" },
    acceptsAttachments: Boolean,
    submitOnEnter: Boolean,
    submitOnCommandReturn: Boolean,
  }

  bindEditors() {
    this.element.querySelectorAll('lexxy-editor[preset="inline"]').forEach((editor) => {
      if (editor.dataset.fileAcceptBound) return

      editor.dataset.fileAcceptBound = "true"
      editor.addEventListener("lexxy:file-accept", this.interceptFile.bind(this))
    })
  }

  interceptFile(event) {
    if (this.acceptsAttachmentsValue) return

    event.preventDefault()
  }

  actionChanged() {
    if (!this.hasActionsSelectTarget) return

    const action = this.actionsSelectTarget.value
    this.actionsSelectTarget.value = ""

    if (action == "attachment") {
      this.pickFile()
    }
  }

  pickFile() {
    if (!this.acceptsAttachmentsValue) return

    const editor = this.element.querySelector(`lexxy-editor[preset="${this.actiontextPresetValue}"]`)
    if (!editor) return

    const input = document.createElement("input")
    input.type = "file"
    input.multiple = true
    input.addEventListener("change", () => {
      for (const file of input.files) {
        editor.dispatchEvent(new CustomEvent("lexxy:file-accept", { detail: { file }, cancelable: true }))
      }
      input.remove()
    })
    input.click()
  }

  typeChanged() {
    if (!this.hasTypeSelectTarget) return

    const previousType = this.typeSelectTarget.dataset.type || this.typeSelectTarget.value
    const type = this.typeSelectTarget.value
    const selectedOption = this.typeSelectTarget.selectedOptions[0]

    this.updateEditorConfig(selectedOption)
    this.updateTypeUi()

    if (!this.editingValue && this.crossedEditorBoundary(previousType, type)) {
      this.swapEditor(type)
    }

    this.typeSelectTarget.dataset.type = type
  }

  crossedEditorBoundary(from, to) {
    return this.editorPresetForType(from) != this.editorPresetForType(to)
  }

  editorPresetForType(type) {
    const option = Array.from(this.typeSelectTarget.options).find((entry) => entry.value == type)
    return option?.dataset.actiontextPreset || "inline"
  }

  updateEditorConfig(option) {
    if (!option) return

    this.actiontextPresetValue = option.dataset.actiontextPreset || "inline"
    this.acceptsAttachmentsValue = option.dataset.acceptsAttachments == "true"
    this.submitOnEnterValue = option.dataset.submitOnEnter == "true"
    this.submitOnCommandReturnValue = option.dataset.submitOnCommandReturn == "true"
  }

  swapEditor(type) {
    const frame = this.element.querySelector("#composer_editor")
    if (!frame || !this.hasEditorUrlValue) return

    const bodyHtml = this.currentBodyHtml()
    const form = document.createElement("form")
    form.method = "post"
    form.action = this.editorUrlValue
    form.setAttribute("data-turbo-frame", "composer_editor")
    form.hidden = true

    this.appendHiddenField(form, "authenticity_token", this.csrfToken())
    this.appendHiddenField(form, "bulletable_type", type)
    if (bodyHtml) this.appendHiddenField(form, "body", bodyHtml)

    document.body.appendChild(form)
    form.requestSubmit()
    form.remove()
  }

  appendHiddenField(form, name, value) {
    const input = document.createElement("input")
    input.type = "hidden"
    input.name = name
    input.value = value
    form.appendChild(input)
  }

  csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content || ""
  }

  currentBodyHtml() {
    const editor = this.element.querySelector("lexxy-editor")
    return editor?.value ?? ""
  }

  updateTypeUi() {
    if (!this.hasTypeSelectTarget) return

    const type = this.typeSelectTarget.value
    this.typeSelectTarget.querySelectorAll(".bullet-form-type-select-marker-item").forEach((marker) => {
      marker.hidden = marker.dataset.type != type
    })
    if (this.hasTypeLabelTarget) {
      this.typeLabelTarget.querySelectorAll("[data-type]").forEach((label) => {
        label.hidden = label.dataset.type != type
      })
    }
    this.typeFieldsTargets.forEach((el) => {
      el.hidden = el.dataset.type != type
    })
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

  onEditorFrameLoad(event) {
    if (event.target.id != "composer_editor") return
    if (!this.element.contains(event.target)) return

    this.bindEditors()
    event.target.querySelector("lexxy-editor")?.focus()
  }

  connect() {
    this.boundFrameLoad = this.onEditorFrameLoad.bind(this)
    this.onSubmit = this.#rememberSubmitter.bind(this)
    document.addEventListener("turbo:frame-load", this.boundFrameLoad)
    this.element.addEventListener("submit", this.onSubmit)

    this.bindEditors()
    if (this.hasTypeSelectTarget) {
      this.typeSelectTarget.dataset.type = this.typeSelectTarget.value
      this.updateEditorConfig(this.typeSelectTarget.selectedOptions[0])
    }
    this.updateTypeUi()
  }

  disconnect() {
    document.removeEventListener("turbo:frame-load", this.boundFrameLoad)
    this.element.removeEventListener("submit", this.onSubmit)
  }

  #rememberSubmitter(event) {
    this.addAnotherSubmit = event.submitter?.name == "add_another"
  }

  clearOnSubmit(event) {
    if (!event.detail.success) return
    if (!this.addAnotherSubmit) return

    this.clearForNextEntry()
  }

  clearForNextEntry() {
    const editor = this.element.querySelector(`lexxy-editor[preset="${this.actiontextPresetValue}"]`)
    if (editor) editor.value = ""
    editor?.focus()
  }

  handleKeydown(event) {
    if (event.isComposing) return

    if (event.ctrlKey && event.shiftKey && event.key == "Tab") {
      if (!this.hasTypeSelectTarget) return

      event.preventDefault()
      this.cycleType(-1)
      return
    }

    if (event.key != "Enter") return

    const commandReturn = event.metaKey || event.ctrlKey

    if (this.submitOnCommandReturnValue) {
      if (!commandReturn) return

      event.preventDefault()
      this.element.requestSubmit()
      return
    }

    if (!this.submitOnEnterValue) return
    if (commandReturn) return

    event.preventDefault()
    this.element.requestSubmit()
  }
}
