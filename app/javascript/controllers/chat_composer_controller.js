import { Controller } from "@hotwired/stimulus"

const TYPE_STORAGE_KEY = "digibujo.composer.type"
const VOICE_TYPE = "Voice"
const NOTE_TYPE = "Note"

// Always-on chat-style bullet composer: one form, one Lexxy editor (note preset),
// a type picker that persists across visits, and an inline voice mode driven by
// voice-recorder. Lexxy points at an external <lexxy-toolbar id="composer_toolbar">
// under the field via toolbar= — never reparent (disconnect disposes setEditor).
export default class extends Controller {
  static targets = [
    "form", "editor", "typeField", "typeIcon", "typeOption", "composeRow",
    "voicePanel", "submit", "voiceSubmit", "toolbarButton", "toolbarPanel",
    "clearButton", "recordButton"
  ]

  connect() {
    this.typeBeforeVoice = null
    this.restingLayoutHeight = window.innerHeight
    this.boundSyncKeyboardInset = () => this.#syncKeyboardInset()
    this.boundSyncTabbarInset = () => this.#syncTabbarInset()
    this.boundOnEditorInitialized = () => {
      this.#prepareToolbar()
      this.#syncPlaceholder()
      this.singleLineHeight = null
      this.#observeEditorHeight()
      this.#syncMultiline()
      this.refresh()
    }

    this.#visualViewport?.addEventListener("resize", this.boundSyncKeyboardInset)
    this.#visualViewport?.addEventListener("scroll", this.boundSyncKeyboardInset)
    window.addEventListener("resize", this.boundSyncTabbarInset)
    window.addEventListener("resize", this.boundSyncKeyboardInset)
    // lexxy:initialize fires straight off the element once the root is mounted.
    // lexxy:editor-initialized goes through Lexxy's adapter, which is a no-op in
    // a browser — never rely on it alone.
    this.editorTarget.addEventListener("lexxy:initialize", this.boundOnEditorInitialized)
    this.editorTarget.addEventListener("lexxy:editor-initialized", this.boundOnEditorInitialized)

    this.#prepareToolbar()
    this.#observeEditorHeight()
    this.#applyType(this.#storedType || this.typeFieldTarget.value)
    this.#syncTabbarInset()
    this.#syncKeyboardInset()
    this.refresh()

    this.#setUpWhenEditorUpgrades()
  }

  disconnect() {
    this.#visualViewport?.removeEventListener("resize", this.boundSyncKeyboardInset)
    this.#visualViewport?.removeEventListener("scroll", this.boundSyncKeyboardInset)
    window.removeEventListener("resize", this.boundSyncTabbarInset)
    window.removeEventListener("resize", this.boundSyncKeyboardInset)
    this.editorTarget.removeEventListener("lexxy:initialize", this.boundOnEditorInitialized)
    this.editorTarget.removeEventListener("lexxy:editor-initialized", this.boundOnEditorInitialized)
    this.resizeObserver?.disconnect()
    this.element.classList.remove("composer--keyboard-open")
    this.element.style.removeProperty("--composer-keyboard-inset")
    this.element.style.removeProperty("--composer-tabbar-inset")
  }

  selectType(event) {
    const type = event.currentTarget.dataset.composerType
    if (!type) return

    this.#applyType(type)
    this.#storeType(type)
    this.refresh()
    this.focus()
  }

  // Field click focuses the editor — but never when the click already landed
  // inside <lexxy-editor> or the formatting toolbar under the field.
  focus(event) {
    if (event?.target instanceof Element) {
      if (event.target.closest("lexxy-editor")) return
      if (event.target.closest("lexxy-toolbar, #composer_toolbar")) return
    }

    this.editorTarget.focus()
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
    if (event.isComposing) return

    if (this.#handleTypeCycleKey(event)) return
    if (this.#handleToolbarKey(event)) return
    if (this.#handleRecordKey(event)) return

    if (event.key !== "Enter") return
    if (event.shiftKey) return
    if (this.#toolbarOpen) return
    if (this.#touchDevice) return
    if (this.editorTarget.hasOpenPrompt) return

    const isModEnter = event.metaKey || event.ctrlKey
    if (this.typeFieldTarget.value === NOTE_TYPE) {
      if (!isModEnter) return
    } else if (isModEnter) {
      return
    }

    event.preventDefault()
    event.stopPropagation()
    this.submit()
  }

  submit() {
    if (!this.#submittable) return

    this.formTarget.requestSubmit()
  }

  startVoice() {
    this.#hideToolbar()
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

  toggleToolbar() {
    if (this.#toolbarOpen) {
      this.#hideToolbar()
      return
    }

    if (!this.#toolbarToggleable) return

    this.#showToolbar()
  }

  clear() {
    this.editorTarget.value = ""
    this.element.classList.remove("composer--multiline")
    this.#hideToolbar()
    this.refresh()
    this.focus()
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
    this.element.classList.remove("composer--multiline")
    this.#hideToolbar()
    this.#applyType(this.typeBeforeVoice || this.#storedType)
    this.typeBeforeVoice = null
    this.refresh()
  }

  // Keep send / mic / toolbar / clear visibility and wrap-aware layout in sync.
  // Formatting is Note-only (always, not only after multiline); clear shows for a
  // multiline draft with text.
  refresh() {
    const ready = this.#submittable
    this.submitTarget.disabled = !ready
    if (this.hasVoiceSubmitTarget) this.voiceSubmitTarget.disabled = !ready
    this.recordButtonTarget.hidden = this.#voiceMode || !this.editorTarget.isBlank
    this.#syncMultiline()
    this.toolbarButtonTarget.hidden = !this.#toolbarToggleable
    this.clearButtonTarget.hidden = !this.#clearable
  }

  // Lexxy defines its custom elements from a setTimeout, so a lazily loaded
  // controller can connect while <lexxy-editor> is still an unknown element —
  // one where editorContentElement, the toolbar template and isBlank are all
  // missing. Run setup again once the upgrade lands.
  #setUpWhenEditorUpgrades() {
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
    if (!this.hasToolbarPanelTarget) return

    const toolbar = this.toolbarPanelTarget
    this.#bootstrapToolbar(toolbar)
    this.#disableLexxyOverflow(toolbar)

    if (this.editorTarget.editor && typeof toolbar.setEditor === "function") {
      if (toolbar.editorElement !== this.editorTarget) {
        toolbar.setEditor(this.editorTarget)
        this.#disableLexxyOverflow(toolbar)
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
  #disableLexxyOverflow(toolbar) {
    toolbar.requestOverflowRefresh = () => {}

    const overflow = toolbar.querySelector(".lexxy-editor__toolbar-overflow")
    const menu = overflow?.querySelector(":scope > [data-dropdown-panel], .lexxy-editor__toolbar-overflow-menu")
    if (!menu) return

    while (menu.firstChild) {
      const item = menu.firstChild
      item.removeAttribute("role")
      toolbar.insertBefore(item, overflow)
    }
  }

  #showToolbar() {
    this.element.classList.add("composer--toolbar")
    if (this.hasToolbarPanelTarget) {
      this.toolbarPanelTarget.setAttribute("aria-hidden", "false")
      this.toolbarPanelTarget.removeAttribute("inert")
    }
    this.#syncToolbarButton(true)
  }

  #hideToolbar() {
    this.element.classList.remove("composer--toolbar")
    if (this.hasToolbarPanelTarget) {
      this.toolbarPanelTarget.setAttribute("aria-hidden", "true")
      this.toolbarPanelTarget.setAttribute("inert", "")
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
    if (this.#voiceMode) return false

    event.preventDefault()
    event.stopPropagation()
    this.#cycleType()
    return true
  }

  #handleToolbarKey(event) {
    if (event.key !== "e" && event.key !== "E") return false
    if (!event.shiftKey || !event.ctrlKey || event.metaKey || event.altKey) return false
    if (!this.#toolbarToggleable && !this.#toolbarOpen) return false

    event.preventDefault()
    event.stopPropagation()
    this.toggleToolbar()
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
    this.toolbarButtonTarget.hidden = !this.#toolbarToggleable
    this.clearButtonTarget.hidden = !this.#clearable
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
      || this.toolbarPanelTarget?.contains(document.activeElement)

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
    if (this.#voiceMode) return this.#hasRecording
    // Before the upgrade isBlank is undefined, which would read as "has text".
    if (!this.editorTarget.editorContentElement) return false

    return !this.editorTarget.isBlank
  }

  get #toolbarToggleable() {
    if (this.#toolbarOpen) return true

    return !this.#voiceMode && this.typeFieldTarget.value === NOTE_TYPE
  }

  get #clearable() {
    if (this.#voiceMode) return false
    if (!this.element.classList.contains("composer--multiline")) return false

    return !this.editorTarget.isBlank
  }

  get #voiceMode() {
    return this.typeFieldTarget.value === VOICE_TYPE
  }

  get #hasRecording() {
    return this.formTarget.querySelector('input[type="file"]')?.files?.length > 0
  }

  get #toolbarOpen() {
    return this.element.classList.contains("composer--toolbar")
  }

  get #visualViewport() {
    return window.visualViewport
  }

  // Soft keyboards treat Enter as newline; don't send on touch / coarse pointers.
  get #touchDevice() {
    return window.matchMedia("(pointer: coarse)").matches ||
      window.matchMedia("(hover: none)").matches
  }
}
