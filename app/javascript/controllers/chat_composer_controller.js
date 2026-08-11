import { Controller } from "@hotwired/stimulus"
import { scrollToBottom } from "helpers/scroll_helpers"

const TYPE_STORAGE_NAME = "digibujo.composer.type"

// Always-on chat-style bullet composer: one form, one Lexxy editor (note preset),
// a type picker that persists across visits, and an inline voice mode driven by
// voice-recorder. Lexxy points at an external <lexxy-toolbar id="composer_toolbar">
// under the field via toolbar= — never reparent (disconnect disposes setEditor).
//
// Keyboard/visual-viewport spacing is handled by a separate controller
// (keyboard_spacing_controller) stacked on the same element — see
// data-controller="composer keyboard-spacing" in the view.
export default class extends Controller {
  static targets = [
    "form", "editor", "typeElement", "typeIcon", "typeOption", "composerRail",
    "recorderWrap", "submit", "submitFinished", "toolbarButton", "toolbarWrap",
    "cleanupButton", "recordButton", "bucketId", "popsOn", "typePicker"
  ]
  static values = { voice: { type: Boolean, default: true } }

  connect() {
    this.typeBeforeVoice = null
    this.initializedContentElement = null
    this.boundOnEditorInitialized = () => this.#initializeEditorIfChanged()

    // lexxy:initialize fires straight off the element once the root is mounted.
    // lexxy:editor-initialized goes through Lexxy's adapter, which is a no-op in
    // a browser — never rely on it alone. Both are wired for safety, so
    // #initializeEditorIfChanged guards against either firing twice for the
    // same content element.
    this.editorTarget.addEventListener("lexxy:initialize", this.boundOnEditorInitialized)
    this.editorTarget.addEventListener("lexxy:editor-initialized", this.boundOnEditorInitialized)

    this.#switchType(this.#storedType || this.typeElementTarget.value)
    this.#initializeEditorWhenReady()
  }

  disconnect() {
    this.editorTarget.removeEventListener("lexxy:initialize", this.boundOnEditorInitialized)
    this.editorTarget.removeEventListener("lexxy:editor-initialized", this.boundOnEditorInitialized)
    this.resizeObserver?.disconnect()
  }

  selectType(event) {
    const type = event.currentTarget.dataset.composerType
    if (!type) return

    this.#switchType(type)
    this.#saveTypeInLS(type)
  }

  // Field click focuses the editor — but never when the click already landed
  // inside <lexxy-editor> or the formatting toolbar under the field.
  refocus(event) {
    if (event?.target instanceof Element && event.target.closest("lexxy-editor, lexxy-toolbar, #composer_toolbar")) {
      return
    }
    this.editorTarget.focus({ preventScroll: false })
  }

  // Desktop send: Notes need Cmd/Ctrl+Enter (plain Enter inserts a newline);
  // Task/Event send on Enter. Shift+Enter always breaks the line. On touch /
  // coarse pointers neither Enter nor Cmd/Ctrl+Enter sends — use the submit
  // control. While the formatting toolbar is open, or a Lexxy prompt
  // (@mention, /command) is open, Enter always breaks the line. Runs on
  // capture so Lexical never sees a sending Enter.
  keydown(event) {
    event.stopPropagation()
    if (event.isComposing) return
    if (this.#handleShortcuts(event)) return
    if (this.#toolbarOpen || this.#mobileDevice || this.editorTarget.hasOpenPrompt) return
    if (!this.allowedKeydownSubmit(event)) return

    event.preventDefault()
    this.submit()
  }

  allowedKeydownSubmit(event) {
    const type = this.typeElementTarget.value
    if (type === "Note") return event.key === "Enter" && event.metaKey
    if (type === "Task" || type === "Event") return event.key === "Enter"
    return false
  }

  // Shift+Tab cycles Note → Task → Event. Shift+Ctrl+Cmd+E toggles the Note
  // toolbar. Shift+R starts a voice take (the mic's own hotkey binding
  // ignores the editor; this is what covers the focused field). Each entry
  // owns its availability check, so an unavailable shortcut (e.g. Shift+R
  // with voice off) just falls through to normal typing.
  #handleShortcuts(event) {
    const shortcuts = [
      {
        matches: event.key === "Tab" && event.shiftKey,
        available: !this.#recorderMode,
        command: () => this.#switchToNextVariant(),
      },
      {
        matches: event.key === "e" && event.shiftKey && event.ctrlKey && event.metaKey,
        available: this.#toolbarToggleable,
        command: () => this.toggleToolbar(),
      },
      {
        matches: event.key === "r" && event.shiftKey,
        available: !this.recordButtonTarget.hidden && !this.#recorderMode,
        command: () => this.recordButtonTarget.click(),
      },
    ]

    const shortcut = shortcuts.find((s) => s.matches && s.available)
    if (!shortcut) return false

    event.preventDefault()
    shortcut.command()
    return true
  }

  submit() {
    this.formTarget.requestSubmit()
  }

  switchToRecorderMode() {
    this.#changeToolbarOpenStatus(false)
    this.typeBeforeVoice = this.typeElementTarget.value
    this.#switchType("Voice")
    this.composerRailTarget.hidden = true
    this.recorderWrapTarget.hidden = false
    this.refresh()
  }

  switchToTextMode() {
    this.#returnToTextMode()
    this.refresh()
  }

  preventBlur(event) {
    if (this.editorTarget.currentlyFocused) event.preventDefault()
  }

  toggleToolbar() {
    const isFocused = this.editorTarget.currentlyFocused
    if (this.#toolbarOpen) {
      this.#changeToolbarOpenStatus(false)
      return
    }

    if (!this.#toolbarToggleable) return

    this.#changeToolbarOpenStatus(true)
    this.#growMultiline()

    if (!isFocused) return
    this.editorTarget.focus()
  }

  cleanup() {
    this.#resetDraft()
    this.refresh()
    this.refocus()
  }

  submitFinished(event) {
    if (!event.detail.success) return

    this.reinitializeComposer()
    this.#scrollToLatest()
  }

  reinitializeComposer() {
    this.#resetDraft()
    this.#returnToTextMode()
    this.refresh()
  }

  // Keep send / mic / toolbar / clear visibility and wrap-aware layout in sync.
  // Formatting is Note-only (always, not only after multiline); clear shows for a
  // multiline draft with text.
  refresh() {
    if (this.hasRecordButtonTarget) {
      this.recordButtonTarget.hidden =
        !this.voiceValue || this.#recorderMode || !this.editorTarget.isBlank
    }
    this.#syncMultiline()
    this.toolbarButtonTarget.hidden = !this.#toolbarToggleable
    this.cleanupButtonTarget.hidden = !this.#clearable
  }

  // Clears the draft itself: editor content, multiline layout, open toolbar.
  // Shared by cleanup() (stay in current mode) and reinitializeComposer()
  // (also returning from voice mode — see #returnToTextMode).
  #resetDraft() {
    this.editorTarget.value = ""
    this.element.classList.remove("composer--multiline")
    this.#changeToolbarOpenStatus(false)
  }

  // Leaves voice mode and restores whichever type was active before it.
  #returnToTextMode() {
    this.recorderWrapTarget.hidden = true
    this.composerRailTarget.hidden = false
    this.#switchType(this.typeBeforeVoice || this.#storedType || "Note")
    this.typeBeforeVoice = null
  }

  #applyVariants(variants) {
    const names = variants.map(String).filter((name) => name !== "Voice")
    this.voiceValue = variants.map(String).includes("Voice")

    this.typeOptionTargets.forEach((option) => {
      option.hidden = !names.includes(option.dataset.composerType)
    })
  }

  // Lexxy defines its custom elements from a setTimeout, so a lazily loaded
  // controller can connect while <lexxy-editor> is still an unknown element —
  // one where editorContentElement, the toolbar template and isBlank are all
  // missing. Run the full init once the upgrade lands, instead of doing a
  // partial pass now and a second full pass later.
  #initializeEditorWhenReady() {
    if (this.editorTarget.editorContentElement) {
      this.#initializeEditorIfChanged()
      return
    }

    customElements.whenDefined("lexxy-editor").then(() => {
      if (!this.element.isConnected) return

      this.#initializeEditorIfChanged()
    })
  }

  // Single entry point for (re)initializing against the editor's content
  // element. Skips the work if we've already initialized against this exact
  // node, so a same-tick lexxy:initialize + lexxy:editor-initialized (or a
  // whenDefined() resolution racing an event) can't trigger a duplicate pass.
  #initializeEditorIfChanged() {
    const content = this.editorTarget.editorContentElement
    if (content && content === this.initializedContentElement) return
    this.initializedContentElement = content

    this.#prepareToolbar()
    this.#syncPlaceholder()
    this.singleLineHeight = null
    this.#observeEditorHeight()
    this.#syncMultiline()
    this.refresh()
  }

  // External <lexxy-toolbar id="composer_toolbar"> starts empty; seed Lexxy's
  // default controls (and re-bind if the editor already attached to a blank one).
  #prepareToolbar() {
    if (!this.hasToolbarWrapTarget) return

    const toolbar = this.toolbarWrapTarget
    this.#bootstrapToolbar(toolbar)

    if (this.editorTarget.editor && typeof toolbar.setEditor === "function") {
      if (toolbar.editorElement !== this.editorTarget) {
        toolbar.setEditor(this.editorTarget)
      }
    }
  }

  #bootstrapToolbar(toolbar) {
    if (toolbar.querySelector("[data-command]")) return

    const Toolbar = customElements.get("lexxy-toolbar")
    const template = Toolbar?.defaultTemplate
    if (!template) return

    toolbar.innerHTML = template
    if (!toolbar.hasAttribute("data-upload")) toolbar.setAttribute("data-upload", "both")
    if (!toolbar.hasAttribute("data-attachments")) {
      toolbar.setAttribute("data-attachments", "true")
    }

    // Match TrimToolbarExtension — keep the composer toolbar compact.
    toolbar.querySelector('button[name="underline"]')?.remove()
    toolbar.querySelector('button[name="quote"]')?.remove()
    toolbar.querySelector('button[name="undo"]')?.remove()
    toolbar.querySelector('button[name="redo"]')?.remove()
    toolbar.querySelector("lexxy-link-dropdown")?.remove()
    toolbar.querySelector("lexxy-highlight-dropdown")?.remove()
    toolbar.querySelector('button[name="format"]')?.closest("lexxy-toolbar-dropdown")?.remove()
    toolbar.querySelectorAll(".lexxy-editor__toolbar-group-end").forEach((button) => {
      button.classList.remove("lexxy-editor__toolbar-group-end")
    })
    toolbar.querySelectorAll(".lexxy-editor__toolbar-separator").forEach((el) => el.remove())
  }

  #changeToolbarOpenStatus(status) {
    this.element.classList.toggle("composer--toolbar-open", status)
    if (this.hasToolbarWrapTarget) {
      this.toolbarWrapTarget.setAttribute("aria-hidden", String(!status))
      this.toolbarWrapTarget.toggleAttribute("inert", !status)
    }
    this.#syncToolbarButton(status)
  }

  #syncToolbarButton(pressed) {
    if (!this.hasToolbarButtonTarget) return

    this.toolbarButtonTarget.setAttribute("aria-pressed", String(pressed))
    this.toolbarButtonTarget.setAttribute("aria-expanded", String(pressed))
    this.toolbarButtonTarget.setAttribute(
      "aria-label",
      pressed ? "Hide formatting toolbar" : "Show formatting toolbar"
    )
  }

  #switchType(type) {
    const name = type || this.typeElementTarget.value
    this.typeElementTarget.value = name
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

  #syncPlaceholder() {
    const selected = this.typeOptionTargets.find(
      (option) => option.dataset.composerType === this.typeElementTarget.value
    )
    const text = selected?.dataset.composerPlaceholder
    if (!text) return

    const editor = this.editorTarget
    editor.setAttribute("placeholder", text)
    editor.editorContentElement?.setAttribute("placeholder", text)
  }

  #switchToNextVariant() {
    const variants = this.#availableVariants
    if (variants.length === 0) return

    const index = variants.indexOf(this.typeElementTarget.value)
    const nextVariant = variants[(index + 1) % variants.length]
    this.#switchType(nextVariant)
    this.#saveTypeInLS(nextVariant)
    this.refresh()
  }

  get #availableVariants() {
    return this.typeOptionTargets
      .filter((option) => !option.hidden)
      .map((option) => option.dataset.composerType)
  }

  #scrollToLatest() {
    scrollToBottom(document.body)
  }

  #observeEditorHeight() {
    if (typeof ResizeObserver === "undefined") return

    this.resizeObserver?.disconnect()
    this.resizeObserver = new ResizeObserver(() => this.#syncMultiline())
    const content = this.editorTarget.editorContentElement ?? this.editorTarget
    this.resizeObserver.observe(content)
  }

  // Once the editor wraps past a single line (or an attachment lands), latch
  // multiline chrome until reset. Flipping back on every height blip made the
  // controls jump while the user was still editing.
  #syncMultiline() {
    if (this.element.classList.contains("composer--multiline")) return

    if (this.#withBlockedContent()) {
      this.#growMultiline()
      return
    }

    const content = this.editorTarget.editorContentElement ?? this.editorTarget
    const height = content.offsetHeight
    if (!height) return

    if (this.editorTarget.isBlank) this.singleLineHeight = height
    if (!this.singleLineHeight) return

    if (height > this.singleLineHeight + 4) this.#growMultiline()
  }

  // Only cleanupButton depends on the multiline class (via #clearable) —
  // toolbarButton's visibility (#toolbarToggleable) never changes with it, so
  // there's nothing else here to re-sync. Callers that need the rest of the
  // dock re-evaluated (submit/record button) call refresh() themselves.
  #growMultiline() {
    this.element.classList.add("composer--multiline")
    this.cleanupButtonTarget.hidden = !this.#clearable
  }

  // A single embedded attachment, table, or list is enough to force
  // multiline chrome regardless of text height.
  #withBlockedContent() {
    return Boolean(
      this.editorTarget.editorContentElement?.querySelector(
        "figure.attachment, action-text-attachment, table, ul, ol"
      )
    )
  }

  #saveTypeInLS(type) {
    try {
      window.localStorage?.setItem(TYPE_STORAGE_NAME, type)
    } catch {
      // Private mode and storage-blocked browsers just lose the preference.
    }
  }

  get #storedType() {
    let stored = null
    try {
      stored = window.localStorage?.getItem(TYPE_STORAGE_NAME)
    } catch {
      stored = null
    }

    const known = this.#availableVariants.includes(stored)
    return known ? stored : this.#availableVariants[0]
  }

  get #toolbarToggleable() {
    if (this.#toolbarOpen) return true

    return !this.#recorderMode && this.typeElementTarget.value === "Note"
  }

  get #clearable() {
    if (this.#recorderMode) return false
    if (!this.element.classList.contains("composer--multiline")) return false

    return !this.editorTarget.isBlank
  }

  get #recorderMode() {
    return this.typeElementTarget.value === "Voice"
  }

  get #toolbarOpen() {
    return this.element.classList.contains("composer--toolbar-open")
  }

  // Soft keyboards treat Enter as newline; don't send on touch / coarse pointers.
  get #mobileDevice() {
    return window.matchMedia("(pointer: coarse)").matches ||
      window.matchMedia("(hover: none)").matches
  }
}