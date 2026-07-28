import { Controller } from "@hotwired/stimulus"

const TYPE_STORAGE_KEY = "digibujo.composer.type"
const VOICE_TYPE = "Voice"
const NOTE_TYPE = "Note"

// Always-on chat-style bullet composer: one form, one Lexxy editor (note preset
// so the toolbar exists once), a type picker that persists across visits, and
// an inline voice mode driven by voice-recorder on the same element.
export default class extends Controller {
  static targets = ["form", "editor", "typeField", "typeIcon", "typeOption", "composeRow", "voicePanel", "submit", "voiceSubmit", "expandButton", "uploadButton", "recordButton"]


  connect() {
    this.typeBeforeVoice = null
    this.restingLayoutHeight = window.innerHeight
    this.boundSyncKeyboardInset = () => this.#syncKeyboardInset()
    this.boundSyncTabbarInset = () => this.#syncTabbarInset()
    this.boundOnEditorInitialized = () => {
      this.#syncPlaceholder()
      this.singleLineHeight = null
      this.#observeEditorHeight()
      this.#syncMultiline()
    }

    this.#visualViewport?.addEventListener("resize", this.boundSyncKeyboardInset)
    this.#visualViewport?.addEventListener("scroll", this.boundSyncKeyboardInset)
    window.addEventListener("resize", this.boundSyncTabbarInset)
    window.addEventListener("resize", this.boundSyncKeyboardInset)
    this.editorTarget.addEventListener("lexxy:editor-initialized", this.boundOnEditorInitialized)

    this.#observeEditorHeight()
    this.#applyType(this.#storedType || this.typeFieldTarget.value)
    this.#syncTabbarInset()
    this.#syncKeyboardInset()
    this.refresh()
  }

  disconnect() {
    this.#visualViewport?.removeEventListener("resize", this.boundSyncKeyboardInset)
    this.#visualViewport?.removeEventListener("scroll", this.boundSyncKeyboardInset)
    window.removeEventListener("resize", this.boundSyncTabbarInset)
    window.removeEventListener("resize", this.boundSyncKeyboardInset)
    this.editorTarget.removeEventListener("lexxy:editor-initialized", this.boundOnEditorInitialized)
    this.resizeObserver?.disconnect()
    this.element.classList.remove("composer--keyboard-open")
    this.element.style.removeProperty("--composer-keyboard-inset")
    this.element.style.removeProperty("--composer-tabbar-inset")
  }

  selectType(event) {
    if (this.#fullscreen) return

    const type = event.currentTarget.dataset.composerType
    if (!type) return

    this.#applyType(type)
    this.#storeType(type)
    this.refresh()
    this.focus()
  }

  focus() {
    this.editorTarget.focus()
  }

  // Enter sends, Shift+Enter breaks the line, and expand always breaks the
  // line. Shift+Tab cycles Note → Task → Event. Shift+Ctrl+E expands Note.
  // Shift+R starts a voice take (hotkey on the mic ignores the editor; this
  // path covers the focused field). Runs on capture so Lexical never sees a
  // sending Enter.
  keydown(event) {
    if (event.isComposing) return

    if (this.#handleTypeCycleKey(event)) return
    if (this.#handleExpandKey(event)) return
    if (this.#handleRecordKey(event)) return

    if (event.key !== "Enter") return
    if (event.shiftKey || event.metaKey || event.ctrlKey) return
    if (this.#fullscreen) return
    if (this.editorTarget.hasOpenPrompt) return

    event.preventDefault()
    event.stopPropagation()
    this.submit()
  }

  submit() {
    if (!this.#submittable) return

    this.formTarget.requestSubmit()
  }

  startVoice() {
    this.typeBeforeVoice = this.typeFieldTarget.value
    this.#applyType(VOICE_TYPE)
    this.composeRowTarget.hidden = true
    this.voicePanelTarget.hidden = false
    this.refresh()
  }

  cancelVoice() {
    this.voicePanelTarget.hidden = true
    this.composeRowTarget.hidden = false
    this.#applyType(this.typeBeforeVoice || this.#storedType)
    this.typeBeforeVoice = null
    this.refresh()
  }

  toggleFullscreen() {
    if (this.#fullscreen) {
      this.#collapseFullscreen()
      return
    }

    this.#expandFullscreen()
  }

  submitEnd(event) {
    if (!event.detail.success) return

    this.reset()
    this.#scrollToLatest()
  }

  reset() {
    this.editorTarget.value = ""
    this.voicePanelTarget.hidden = true
    this.composeRowTarget.hidden = false
    this.element.classList.remove("composer--fullscreen", "composer--multiline")
    this.expandButtonTarget.setAttribute("aria-pressed", "false")
    this.expandButtonTarget.setAttribute("aria-label", "Expand editor")
    this.#applyType(this.typeBeforeVoice || this.#storedType)
    this.typeBeforeVoice = null
    this.refresh()
  }

  // Keep send / mic / expand / upload visibility and wrap-aware layout in sync.
  // Expand is Note-only and waits for a second line; upload is Note-only always.
  refresh() {
    const ready = this.#submittable
    this.submitTarget.disabled = !ready
    if (this.hasVoiceSubmitTarget) this.voiceSubmitTarget.disabled = !ready
    this.recordButtonTarget.hidden = this.#voiceMode || !this.editorTarget.isBlank
    this.#syncMultiline()
    this.expandButtonTarget.hidden = !this.#expandable
    this.uploadButtonTarget.hidden = !this.#uploadable
  }

  // Proxy to Lexxy's hidden toolbar control so uploads stay in the same pipeline.
  uploadFile() {
    if (!this.#uploadable) return

    this.editorTarget.querySelector('lexxy-toolbar button[name="file"]')?.click()
  }

  #expandFullscreen() {
    this.element.classList.add("composer--fullscreen")
    this.expandButtonTarget.setAttribute("aria-pressed", "true")
    this.expandButtonTarget.setAttribute("aria-label", "Collapse editor")
    this.refresh()
    this.focus()
  }

  // Same Lexxy instance — expand only reveals the toolbar via CSS. Keep the
  // draft; no remount, no confirm.
  #collapseFullscreen() {
    this.element.classList.remove("composer--fullscreen")
    this.expandButtonTarget.setAttribute("aria-pressed", "false")
    this.expandButtonTarget.setAttribute("aria-label", "Expand editor")
    this.refresh()
    this.focus()
  }

  #applyType(type) {
    const name = type || this.typeFieldTarget.value
    this.typeFieldTarget.value = name
    this.element.dataset.bulletType = name.toLowerCase()

    this.typeIconTargets.forEach((icon) => {
      icon.hidden = icon.dataset.composerType !== name
    })

    this.typeOptionTargets.forEach((option) => {
      const selected = option.dataset.composerType === name
      option.setAttribute("aria-checked", String(selected))
    })

    this.#syncPlaceholder()
  }

  // Lexxy paints via `attr(placeholder)` on `.lexxy-editor__content`, which is
  // only copied from the host at mount. Updating the host alone leaves the SSR
  // Note placeholder stuck on screen — write both, and re-run after remounts.
  #syncPlaceholder() {
    const selected = this.typeOptionTargets.find(
      (option) => option.dataset.composerType === this.typeFieldTarget.value
    )
    const text = selected?.dataset.composerPlaceholder
    if (!text) return

    const editor = this.editorTarget
    editor.setAttribute("placeholder", text)
    editor.editorContentElement?.setAttribute("placeholder", text)
  }

  #handleTypeCycleKey(event) {
    if (event.key !== "Tab" || !event.shiftKey) return false
    if (event.metaKey || event.ctrlKey || event.altKey) return false
    if (this.#fullscreen || this.#voiceMode) return false

    event.preventDefault()
    event.stopPropagation()
    this.#cycleType()
    return true
  }

  #handleExpandKey(event) {
    if (event.key !== "e" && event.key !== "E") return false
    if (!event.shiftKey || !event.ctrlKey || event.metaKey || event.altKey) return false
    if (!this.#expandable) return false

    event.preventDefault()
    event.stopPropagation()
    this.toggleFullscreen()
    return true
  }

  #handleRecordKey(event) {
    if (event.key !== "r" && event.key !== "R") return false
    if (!event.shiftKey || event.metaKey || event.ctrlKey || event.altKey) return false
    if (this.recordButtonTarget.hidden || this.#voiceMode) return false

    event.preventDefault()
    event.stopPropagation()
    this.recordButtonTarget.click()
    return true
  }

  #cycleType() {
    const types = this.typeOptionTargets.map((option) => option.dataset.composerType)
    if (types.length === 0) return

    const index = types.indexOf(this.typeFieldTarget.value)
    const next = types[(index + 1) % types.length]
    this.#applyType(next)
    this.#storeType(next)
    this.refresh()
    this.focus()
  }

  #scrollToLatest() {
    const rows = document.querySelector('[id$="_bullets_container"]')?.querySelectorAll(".bullet")
    rows?.[rows.length - 1]?.scrollIntoView({ block: "center", behavior: "smooth" })
  }

  #observeEditorHeight() {
    if (typeof ResizeObserver === "undefined") return

    this.resizeObserver?.disconnect()
    this.resizeObserver = new ResizeObserver(() => this.#syncMultiline())
    // Measure the content box, not the whole editor — the compact uploadFile
    // control keeps lexxy-editor tall even on a blank one-liner.
    const content = this.editorTarget.editorContentElement ?? this.editorTarget
    this.resizeObserver.observe(content)
  }

  // Once the editor wraps past a single line (or an attachment lands), latch
  // multiline chrome until reset. Flipping back on every height blip made the
  // controls jump while the user was still editing.
  #syncMultiline() {
    if (this.element.classList.contains("composer--multiline")) return

    if (this.#hasAttachment()) {
      this.#latchMultiline()
      return
    }

    const content = this.editorTarget.editorContentElement ?? this.editorTarget
    const height = content.offsetHeight
    if (!height) return

    if (this.editorTarget.isBlank) this.singleLineHeight = height
    if (!this.singleLineHeight) return

    if (height > this.singleLineHeight + 4) this.#latchMultiline()
  }

  #latchMultiline() {
    this.element.classList.add("composer--multiline")
    this.expandButtonTarget.hidden = !this.#expandable
  }

  #hasAttachment() {
    const root = this.editorTarget.editorContentElement
    if (!root) return false

    return Boolean(root.querySelector("figure.attachment, action-text-attachment"))
  }

  #syncKeyboardInset() {
    const viewport = this.#visualViewport
    if (!viewport) return

    const focused = this.element.contains(document.activeElement)

    // Overlay keyboard: layout stays tall, VV shrinks → bottom = inset.
    const overlayInset = Math.max(
      0,
      Math.round(window.innerHeight - viewport.height - viewport.offsetTop)
    )

    // resizes-content: layout already shrank → overlayInset ~0; still treat as
    // keyboard-open so bottom:0 sits on the keyboard and the tabbar is hidden.
    if (!focused) this.restingLayoutHeight = window.innerHeight
    const resizeDelta = Math.max(
      0,
      Math.round((this.restingLayoutHeight ?? window.innerHeight) - window.innerHeight)
    )
    const keyboardOpen = overlayInset > 0 || (focused && resizeDelta > 50)

    this.element.style.setProperty("--composer-keyboard-inset", `${overlayInset}px`)
    this.element.classList.toggle("composer--keyboard-open", keyboardOpen)
  }

  // Fixed composer clears the floating tabbar while the keyboard is closed.
  #syncTabbarInset() {
    const tabbar = document.querySelector(".tabbar--navigation")
    const inset = tabbar
      ? Math.max(0, Math.round(window.innerHeight - tabbar.getBoundingClientRect().top))
      : 0

    this.element.style.setProperty("--composer-tabbar-inset", `${inset}px`)
  }

  #storeType(type) {
    try {
      window.localStorage?.setItem(TYPE_STORAGE_KEY, type)
    } catch {
      // Private mode and storage-blocked browsers just lose the preference.
    }
  }

  get #storedType() {
    let stored = null
    try {
      stored = window.localStorage?.getItem(TYPE_STORAGE_KEY)
    } catch {
      stored = null
    }

    const known = this.typeOptionTargets.some((option) => option.dataset.composerType === stored)
    return known ? stored : this.typeOptionTargets[0]?.dataset.composerType
  }

  get #submittable() {
    return this.#voiceMode ? this.#hasRecording : !this.editorTarget.isBlank
  }

  get #expandable() {
    if (this.#fullscreen) return true
    if (this.typeFieldTarget.value !== NOTE_TYPE) return false

    return this.element.classList.contains("composer--multiline")
  }

  get #uploadable() {
    return !this.#voiceMode && this.typeFieldTarget.value === NOTE_TYPE
  }

  get #voiceMode() {
    return this.typeFieldTarget.value === VOICE_TYPE
  }

  get #hasRecording() {
    return this.formTarget.querySelector('input[type="file"]')?.files?.length > 0
  }

  get #fullscreen() {
    return this.element.classList.contains("composer--fullscreen")
  }

  get #visualViewport() {
    return window.visualViewport
  }
}
