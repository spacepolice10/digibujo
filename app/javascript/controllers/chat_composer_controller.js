import { Controller } from "@hotwired/stimulus"

const TYPE_STORAGE_KEY = "digibujo.composer.type"
const VOICE_TYPE = "Voice"
const NOTE_TYPE = "Note"
const EXPAND_MIN_CHARS = 80
const COLLAPSE_CONFIRM =
  "Collapse and discard this draft? Rich formatting will be lost."

// Always-on chat-style bullet composer: one form, one inline Lexxy editor, a
// type picker that persists across visits, and an inline voice mode driven by
// the voice-recorder controller mounted on the same element.
export default class extends Controller {
  static targets = ["form", "editor", "typeField", "typeIcon", "typeOption", "composeRow", "voicePanel", "submit", "voiceSubmit", "expandButton", "recordButton"]


  connect() {
    this.typeBeforeVoice = null
    this.boundSyncKeyboardInset = () => this.#syncKeyboardInset()
    this.boundSyncTabbarInset = () => this.#syncTabbarInset()

    this.#visualViewport?.addEventListener("resize", this.boundSyncKeyboardInset)
    this.#visualViewport?.addEventListener("scroll", this.boundSyncKeyboardInset)
    window.addEventListener("resize", this.boundSyncTabbarInset)
    window.addEventListener("resize", this.boundSyncKeyboardInset)

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

  // Enter sends, Shift+Enter breaks the line, and fullscreen always breaks the
  // line. Shift+Tab cycles Note → Task → Event. Shift+Ctrl+E expands when the
  // draft qualifies. Shift+R starts a voice take (hotkey on the mic ignores the
  // editor; this path covers the focused field). Runs on capture so Lexical
  // never sees a sending Enter.
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
    const wasFullscreen = this.#fullscreen
    this.element.classList.remove("composer--fullscreen", "composer--multiline")
    this.expandButtonTarget.setAttribute("aria-pressed", "false")
    this.expandButtonTarget.setAttribute("aria-label", "Expand editor")
    this.#applyType(this.typeBeforeVoice || this.#storedType)
    this.typeBeforeVoice = null

    // Fullscreen swaps the Lexxy preset to `note` (toolbar on); collapse back
    // so the sticky bar does not keep a leftover toolbar after send.
    if (wasFullscreen) this.#syncEditorPreset(false)
    else this.refresh()
  }

  // Keep send / mic / expand visibility and wrap-aware layout in sync with the
  // editor. Expand is Note-only and waits until the draft is long enough to
  // bother with a fullscreen sheet; once open it stays available to collapse.
  refresh() {
    const ready = this.#submittable
    this.submitTarget.disabled = !ready
    if (this.hasVoiceSubmitTarget) this.voiceSubmitTarget.disabled = !ready
    this.recordButtonTarget.hidden = this.#voiceMode || !this.editorTarget.isBlank
    this.expandButtonTarget.hidden = !this.#expandable
    this.#syncMultiline()
  }

  #expandFullscreen() {
    this.#withComposerTransition(() => {
      this.element.classList.add("composer--fullscreen")
      this.expandButtonTarget.setAttribute("aria-pressed", "true")
      this.expandButtonTarget.setAttribute("aria-label", "Collapse editor")
      this.#syncEditorPreset(true)
    })
  }

  // Leaving the note sheet drops toolbar markup the inline preset cannot keep,
  // so collapse discards the whole draft after the user confirms.
  #collapseFullscreen() {
    if (!window.confirm(COLLAPSE_CONFIRM)) return

    this.#withComposerTransition(() => {
      this.editorTarget.value = ""
      this.element.classList.remove("composer--fullscreen", "composer--multiline")
      this.expandButtonTarget.setAttribute("aria-pressed", "false")
      this.expandButtonTarget.setAttribute("aria-label", "Expand editor")
      this.#syncEditorPreset(false)
    })
  }

  #withComposerTransition(apply) {
    if (!this.#canViewTransition) {
      apply()
      return
    }

    // Name the dock for the morph, then suppress the root crossfade so only the
    // composer moves between the chat bar and the fullscreen sheet.
    this.element.classList.add("is-composer-morphing")
    document.documentElement.dataset.chatComposerVt = ""

    document.startViewTransition(apply).finished.finally(() => {
      this.element.classList.remove("is-composer-morphing")
      delete document.documentElement.dataset.chatComposerVt
    })
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
      if (selected) this.editorTarget.setAttribute("placeholder", option.dataset.composerPlaceholder)
    })
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

  // Compact mode uses the `inline` preset (no toolbar). Expanding remounts the
  // same element on `note` so Lexxy builds its toolbar from that preset. Content
  // is kept via Lexxy's valueBeforeDisconnect — call the lifecycle hooks
  // directly; the private #reconnect path clears that snapshot.
  #syncEditorPreset(expanded) {
    const editor = this.editorTarget
    const next = expanded ? "note" : "inline"
    if (editor.getAttribute("preset") === next) {
      this.focus()
      return
    }

    editor.setAttribute("preset", next)
    editor.querySelector("lexxy-toolbar")?.remove()
    editor.disconnectedCallback()
    editor.connectedCallback()

    this.singleLineHeight = null
    requestAnimationFrame(() => {
      this.refresh()
      this.focus()
    })
  }

  #scrollToLatest() {
    const rows = document.querySelector('[id$="_bullets_container"]')?.querySelectorAll(".bullet")
    rows?.[rows.length - 1]?.scrollIntoView({ block: "center", behavior: "smooth" })
  }

  #observeEditorHeight() {
    if (typeof ResizeObserver === "undefined") return

    this.resizeObserver = new ResizeObserver(() => this.#syncMultiline())
    this.resizeObserver.observe(this.editorTarget)
  }

  // Once the editor wraps past a single line, latch the multiline chrome until
  // reset (successful send) or a full page remount. Flipping back on every
  // height blip made the controls jump while the user was still editing.
  #syncMultiline() {
    if (this.element.classList.contains("composer--multiline")) return

    const height = this.editorTarget.offsetHeight
    if (!height) return

    if (this.editorTarget.isBlank) this.singleLineHeight = height
    if (!this.singleLineHeight) return

    if (height > this.singleLineHeight + 4) {
      this.element.classList.add("composer--multiline")
    }
  }

  #syncKeyboardInset() {
    const viewport = this.#visualViewport
    if (!viewport) return

    // iOS overlays the keyboard over the layout viewport; Chromium usually
    // resizes content and leaves this at zero. The tabbar stays put — only the
    // composer rail tracks the keyboard (see composer--keyboard-open in CSS).
    const inset = Math.max(0, Math.round(window.innerHeight - viewport.height - viewport.offsetTop))
    this.element.style.setProperty("--composer-keyboard-inset", `${inset}px`)
    this.element.classList.toggle("composer--keyboard-open", inset > 0)
  }

  // Tabbar clearance when the keyboard is closed. Ignored while typing so the
  // dock sits flush on the keyboard, not stacked above the hidden tabbar.
  #syncTabbarInset() {
    const tabbar = document.querySelector(".tabbar--navigation")
    if (!tabbar) {
      this.element.style.setProperty("--composer-tabbar-inset", "0px")
      return
    }

    const rect = tabbar.getBoundingClientRect()
    const inset = Math.max(0, Math.round(window.innerHeight - rect.top))
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

    return this.typeFieldTarget.value === NOTE_TYPE && this.#characterCount >= EXPAND_MIN_CHARS
  }

  get #characterCount() {
    const root = this.editorTarget.querySelector(".lexxy-editor__content")
    const text = root?.innerText ?? ""
    // Lexical keeps a zero-width placeholder; strip it so an empty field is 0.
    return text.replace(/\u200b/g, "").length
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

  get #canViewTransition() {
    return typeof document.startViewTransition === "function"
      && !matchMedia("(prefers-reduced-motion: reduce)").matches
  }

  get #visualViewport() {
    return window.visualViewport
  }
}
