import { Controller } from "@hotwired/stimulus"
import { scrollToBottom } from "helpers/scroll_helpers"

const TYPE_STORAGE_NAME = "digibujo.composer.type"

// Always-on chat-style bullet composer: one form, one Lexxy editor (note preset),
// a type picker that persists across visits, and an inline voice mode driven by
// voice-recorder. Lexxy points at an external <lexxy-toolbar id="composer_toolbar">
// under the field via toolbar= — never reparent (disconnect disposes setEditor).
export default class extends Controller {
  static targets = [
    "form", "editor", "typeElement", "typeIcon", "typeOption", "composerRail",
    "recorderWrap", "submit", "submitFinished", "toolbarButton", "toolbarWrap",
    "cleanupButton", "recordButton", "bucketId", "popsOn", "typePicker"
  ]
  static values = { voice: { type: Boolean, default: true } }

  connect() {
    this.typeBeforeVoice = null
    this.restingLayoutHeight = window.innerHeight
    this.boundSyncKeyboardSpacing = () => this.#syncKeyboardSpacing()
    this.boundOnEditorInitialized = () => {
      this.#prepareToolbar()
      this.#syncPlaceholder()
      this.singleLineHeight = null
      this.#observeEditorHeight()
      this.#syncMultiline()
      this.refresh()
    }

    this.#visualViewport?.addEventListener("resize", this.boundSyncKeyboardSpacing)
    this.#visualViewport?.addEventListener("scroll", this.boundSyncKeyboardSpacing)
    // lexxy:initialize fires straight off the element once the root is mounted.
    // lexxy:editor-initialized goes through Lexxy's adapter, which is a no-op in
    // a browser — never rely on it alone.
    this.editorTarget.addEventListener("lexxy:initialize", this.boundOnEditorInitialized)
    this.editorTarget.addEventListener("lexxy:editor-initialized", this.boundOnEditorInitialized)

    this.#prepareToolbar()
    this.#observeEditorHeight()
    this.#switchType(this.#storedType || this.typeElementTarget.value)
    this.#syncKeyboardSpacing()
    this.refresh()
    this.#reinitializeWhenEditorUpgrades()
  }

  // Update destination + allowlist without remounting Lexxy. Also rewrites this
  // turbo-frame's id so create.turbo_stream can pair composer → container.
  changeContext({ bucketId, popsOn, variants, composerId } = {}) {
    if (bucketId != null && this.hasBucketIdTarget) {
      this.bucketIdTarget.value = bucketId
    }
    if (this.hasPopsOnTarget) {
      this.popsOnTarget.value = popsOn == null ? "" : popsOn
    }
    if (composerId) this.element.id = composerId
    if (variants) this.#applyVariants(variants)

    const current = this.typeElementTarget.value
    const next = this.#availableVariants.includes(current)
      ? current
      : (this.#storedType || this.#availableVariants[0])
    if (next && next !== current) this.#switchType(next)
    this.refresh()
  }

  disconnect() {
    this.#visualViewport?.removeEventListener("resize", this.boundSyncKeyboardSpacing)
    this.#visualViewport?.removeEventListener("scroll", this.boundSyncKeyboardSpacing)
    this.editorTarget.removeEventListener("lexxy:initialize", this.boundOnEditorInitialized)
    this.editorTarget.removeEventListener("lexxy:editor-initialized", this.boundOnEditorInitialized)
    this.resizeObserver?.disconnect()
    this.element.classList.remove("composer--keyboard-open")
    this.element.style.removeProperty("--composer-keyboard-spacing")
    this.element.style.removeProperty("--composer-tabbar-spacing")
  }

  selectType(event) {
    const type = event.currentTarget.dataset.composerType
    if (!type) return

    this.#switchType(type)
    this.#saveTypeInLS(type)
    this.refresh()
    this.refocus()
  }

  // Field click focuses the editor — but never when the click already landed
  // inside <lexxy-editor> or the formatting toolbar under the field.
  refocus(event) {
    if (event?.target instanceof Element) {
      if (event.target.closest("lexxy-editor")) return
      if (event.target.closest("lexxy-toolbar, #composer_toolbar")) return
    }
      this.editorTarget.focus({ preventScroll: false })
  }

  // Desktop send: Notes need Cmd/Ctrl+Enter (plain Enter inserts a newline);
  // Task/Event send on Enter. Shift+Enter always breaks the line. On touch /
  // coarse pointers neither Enter nor Cmd/Ctrl+Enter sends — use the submit
  // control. While the formatting toolbar is open, Enter always breaks the
  // line. Shift+Tab cycles Note → Task → Event. Shift+Ctrl+E toggles the Note
  // toolbar. Shift+R starts a voice take (hotkey on the mic ignores the
  // editor; this path covers the focused field). Runs on capture so Lexical
  // never sees a sending Enter.
  keydown(event) {
    event.stopPropagation()
    if (event.isComposing) return
    if (this.#handleSwitchToNextVariantKeydown(event)) return
    if (this.#handleToolbarKeydown(event)) return
    if (this.#handleRecordKeydown(event)) return
    if (this.#toolbarOpen) return
    if (this.#mobileDevice) return
    if (this.editorTarget.hasOpenPrompt) return
    if (!this.allowedKeydownSubmit(event)) return

    event.preventDefault()
    this.submit()
  }

  allowedKeydownSubmit(event) {
    const type = this.typeElementTarget.value
    if (type == "Note" && event.key == 'Enter' && event.metaKey) {
      return true
    }
    else if ((type == "Task" || type == "Event") && event.key == "Enter") {
      return true
    }
    return false
  }

  submit() {
    if (!this.#submittable) return

    this.formTarget.requestSubmit()
  }

  switchToRecorderMode() {
    this.#hideToolbar()
    this.typeBeforeVoice = this.typeElementTarget.value
    this.#switchType("Voice")
    this.composerRailTarget.hidden = true
    this.recorderWrapTarget.hidden = false
    this.refresh()
  }

  switchToTextMode() {
    this.recorderWrapTarget.hidden = true
    this.composerRailTarget.hidden = false
    this.#switchType(this.typeBeforeVoice || this.#storedType || "Note")
    this.typeBeforeVoice = null
    this.refresh()
  }

  preventBlur(event) {
    if (this.editorTarget.currentlyFocused) event.preventDefault()
  }

  toggleToolbar() {

    const isFocused = this.editorTarget.currentlyFocused
    if (this.#toolbarOpen) {
      this.#hideToolbar()
      return
    }

    if (!this.#toolbarToggleable) return

    this.#showToolbar()

    if (!isFocused) return
    this.editorTarget.focus()
  }

  cleanup() {
    this.editorTarget.value = ""
    this.element.classList.remove("composer--multiline")
    this.#hideToolbar()
    this.refresh()
    this.refocus()
  }

  submitFinished(event) {
    if (!event.detail.success) return

    this.reinitializeComposer()
    this.#scrollToLatest()
  }

  reinitializeComposer() {
    this.editorTarget.value = ""
    this.recorderWrapTarget.hidden = true
    this.composerRailTarget.hidden = false
    this.element.classList.remove("composer--multiline")
    this.#hideToolbar()
    this.#switchType(this.typeBeforeVoice || this.#storedType || "Note")
    this.typeBeforeVoice = null
    this.refresh()
  }

  // Keep send / mic / toolbar / clear visibility and wrap-aware layout in sync.
  // Formatting is Note-only (always, not only after multiline); clear shows for a
  // multiline draft with text.
  refresh() {
    this.submitTarget.disabled = !this.#submittable
    if (this.hasRecordButtonTarget) {
      this.recordButtonTarget.hidden =
        !this.voiceValue || this.#recorderMode || !this.editorTarget.isBlank
    }
    this.#syncMultiline()
    this.toolbarButtonTarget.hidden = !this.#toolbarToggleable
    this.cleanupButtonTarget.hidden = !this.#clearable
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
  // missing. Run setup again once the upgrade lands.
  #reinitializeWhenEditorUpgrades() {
    if (this.editorTarget.editorContentElement) {
      this.boundOnEditorInitialized()
      return
    }

    customElements.whenDefined("lexxy-editor").then(() => {
      if (!this.element.isConnected) return

      this.boundOnEditorInitialized()
    })
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

  // Prefer CSS horizontal scroll; stop Lexxy from moving controls into its
  // overflow menu (which we hide). One-shot — no restore loops on show.


  #showToolbar() {
    this.element.classList.add("composer--toolbar-open")
    if (this.hasToolbarWrapTarget) {
      this.toolbarWrapTarget.setAttribute("aria-hidden", "false")
      this.toolbarWrapTarget.removeAttribute("inert")
    }
    this.#syncToolbarButton(true)
  }

  #hideToolbar() {
    this.element.classList.remove("composer--toolbar-open")
    if (this.hasToolbarWrapTarget) {
      this.toolbarWrapTarget.setAttribute("aria-hidden", "true")
      this.toolbarWrapTarget.setAttribute("inert", "")
    }
    this.#syncToolbarButton(false)
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

  #handleSwitchToNextVariantKeydown(event) {
    const isShiftTabbed = event.key == "Tab" && event.shiftKey
    if (this.#recorderMode || !isShiftTabbed) return false

    event.preventDefault()
    event.stopPropagation()
    this.#switchToNextVariant()
    return true
  }

  #handleToolbarKeydown(event) {
    const isShiftCtrlE = event.key == "e" && event.shiftKey && event.ctrlKey && event.metaKey
    if (!isShiftCtrlE || !this.#toolbarToggleable) return false

    event.preventDefault()
    event.stopPropagation()
    this.toggleToolbar()
    return true
  }

  #handleRecordKeydown(event) {
    const isShiftR = event.key == "r" && event.shiftKey
    if (!isShiftR || this.recordButtonTarget.hidden || this.#recorderMode) return false

    event.preventDefault()
    event.stopPropagation()
    this.recordButtonTarget.click()
    return true
  }

  #switchToNextVariant() {
    const variants = this.#availableVariants
    if (variants.length === 0) return

    const index = variants.indexOf(this.typeElementTarget.value)
    const nextVariant = variants[(index + 1) % variants.length]
    this.#switchType(nextVariant)
    this.#saveTypeInLS(nextVariant)
    this.refresh()
    this.refocus()
  }

  get #availableVariants() {
    return this.typeOptionTargets
      .filter((option) => !option.hidden)
      .map((option) => option.dataset.composerType)
  }

  #scrollToLatest() {
    const container = this.element.closest(".chat--scroller")
    if (!container) return
    scrollToBottom(container)
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

    if (this.#withAttachment() || this.#withRichData()) {
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

  #growMultiline() {
    this.element.classList.add("composer--multiline")
    this.toolbarButtonTarget.hidden = !this.#toolbarToggleable
    this.cleanupButtonTarget.hidden = !this.#clearable
  }

  #withAttachment() {
    const root = this.editorTarget.editorContentElement
    if (!root) return false

    return Boolean(root.querySelector("figure.attachment, action-text-attachment"))
  }

  #withRichData() {
    const root = this.editorTarget.editorContentElement
    if (!root) return false

    return Boolean(root.querySelector("table, action-text-attachment, ul, ol"))
  }

  #syncKeyboardSpacing() {
    const viewport = this.#visualViewport
    if (!viewport) return

    const focused = this.element.contains(document.activeElement)
      || this.toolbarWrapTarget?.contains(document.activeElement)

    // interactive-widget=resizes-visual: layout / 100dvh stay full, visual
    // viewport shrinks under the keyboard → bottom inset lifts the dock without
    // crushing the chat scroller. (resizes-content was leaving iOS stuck short
    // after dismiss.)
    const overlayInset = Math.max(
      0,
      Math.round(window.innerHeight - viewport.height - viewport.offsetTop)
    )
    // Fallback when a browser still resizes the layout viewport instead: VV
    // inset stays ~0, but innerHeight drops while focused.
    if (!focused) this.restingLayoutHeight = window.innerHeight
    const resizeDelta = Math.max(
      0,
      Math.round((this.restingLayoutHeight ?? window.innerHeight) - window.innerHeight)
    )
    const keyboardOpen = overlayInset > 0 || (focused && resizeDelta > 50)
    if (keyboardOpen) {
      this.element.style.setProperty("--composer-keyboard-spacing", `${overlayInset}px`)
    } else {
      this.element.style.removeProperty("--composer-keyboard-spacing", "0px")
    }
    this.element.classList.toggle("composer--keyboard-open", keyboardOpen)
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

  get #submittable() {
    return true
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

  get #withRecording() {
    return this.formTarget.querySelector('input[type="file"]')?.files?.length > 0
  }

  get #toolbarOpen() {
    return this.element.classList.contains("composer--toolbar-open")
  }

  get #visualViewport() {
    return window.visualViewport
  }

  // Soft keyboards treat Enter as newline; don't send on touch / coarse pointers.
  get #mobileDevice() {
    return window.matchMedia("(pointer: coarse)").matches ||
      window.matchMedia("(hover: none)").matches
  }
}
