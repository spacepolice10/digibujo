import { Controller } from "@hotwired/stimulus"

// Keyed by the turbo-frame element itself (not its id) so a stash never
// outlives the DOM node it was captured from, e.g. across a Drive visit
// that replaces the frame with a fresh element sharing the same id.
const stashes = new WeakMap()
let globalsAttached = false

function attachGlobals() {
  if (globalsAttached) return
  globalsAttached = true

  document.addEventListener("keydown", onKeydown)
  document.addEventListener("turbo:submit-end", onSubmitEnd)
}

function swapWithViewTransition(update) {
  if (document.startViewTransition && !window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
    return document.startViewTransition(update)
  }

  update()
  return null
}

function restorePicker(frame) {
  const content = stashes.get(frame)
  if (!content) return false

  const transition = swapWithViewTransition(() => {
    frame.removeAttribute("src")
    frame.innerHTML = content
  })

  const finish = () => {
    frame.dispatchEvent(new CustomEvent("composer:rebind"))
    frame.querySelector("a, button")?.focus?.()
  }

  if (transition) transition.finished.then(finish)
  else finish()

  return true
}

function frameToCancel() {
  // Scoped to composer-controlled frames specifically (not just any
  // turbo-frame containing one), since composer frames can be nested
  // inside unrelated ancestor frames (e.g. the daylog's page-level frame).
  const candidates = [...document.querySelectorAll('turbo-frame[data-controller~="composer"]')].filter((frame) =>
    frame.querySelector("[data-composer-form]")
  )

  if (candidates.length == 0) return null

  const focused = candidates.find((frame) => {
    return frame.matches(":focus-within") || frame.contains(document.activeElement)
  })
  if (focused) return focused

  if (candidates.length == 1) return candidates[0]

  return null
}

function tryCancelFrame(frame) {
  if (document.querySelector("dialog[open]")) return false

  const form = frame.querySelector("[data-composer-form]")
  if (!form) return false
  if (form.dataset.composerEditing == "true") return false

  return restorePicker(frame)
}

function onKeydown(event) {
  if (event.key != "Escape") return
  if (event.defaultPrevented) return

  const frame = frameToCancel()
  if (!frame) return
  if (!tryCancelFrame(frame)) return

  event.preventDefault()
}

function onSubmitEnd(event) {
  if (!event.detail.success) return

  const form = event.target
  if (!form?.hasAttribute("data-composer-form")) return

  const submitter = event.detail.formSubmission?.submitter
  if (submitter?.name == "another") return

  const frame = form.closest("turbo-frame")
  if (!frame || !stashes.has(frame)) return

  restorePicker(frame)
}

export default class extends Controller {
  connect() {
    attachGlobals()

    this.beforeFrameRender = this.#beforeFrameRender.bind(this)
    this.frameLoad = this.#frameLoad.bind(this)
    this.inlineSubmitKeydown = this.#inlineSubmitKeydown.bind(this)
    this.onSubmit = this.#rememberSubmitter.bind(this)
    this.rebind = this.#rebind.bind(this)

    if (this.#isFrame) {
      this.element.addEventListener("turbo:before-frame-render", this.beforeFrameRender)
      this.element.addEventListener("turbo:frame-load", this.frameLoad)
      this.element.addEventListener("keydown", this.inlineSubmitKeydown, true)
      this.element.addEventListener("composer:rebind", this.rebind)
    }

    this.#bindForm()
  }

  disconnect() {
    if (this.#isFrame) {
      this.element.removeEventListener("turbo:before-frame-render", this.beforeFrameRender)
      this.element.removeEventListener("turbo:frame-load", this.frameLoad)
      this.element.removeEventListener("keydown", this.inlineSubmitKeydown, true)
      this.element.removeEventListener("composer:rebind", this.rebind)
    }

    this.#unbindForm()
  }

  get #isFrame() {
    return this.element.tagName == "TURBO-FRAME"
  }

  get #form() {
    if (this.#isFrame) return this.element.querySelector("[data-composer-form]")
    if (this.element.hasAttribute("data-composer-form")) return this.element

    return null
  }

  #rebind() {
    this.#unbindForm()
  }

  #bindForm() {
    const form = this.#form
    if (!form || form == this.boundForm) return

    this.#unbindForm()
    this.boundForm = form
    form.addEventListener("submit", this.onSubmit)
  }

  #unbindForm() {
    if (!this.boundForm) return

    this.boundForm.removeEventListener("submit", this.onSubmit)
    this.boundForm = null
  }

  #rememberSubmitter(event) {
    this.anotherSubmit = event.submitter?.name == "another"
  }

  clearOnSubmit(event) {
    if (!event.detail.success) return
    if (!this.anotherSubmit) return

    this.clearForNextEntry()
  }

  clearForNextEntry() {
    const form = this.#form
    if (!form) return

    const editor = form.querySelector("lexxy-editor")
    if (editor) editor.value = ""
    editor?.focus()
  }

  submit(event) {
    const form = this.#form
    if (!form) return
    if (event.isComposing) return

    event.preventDefault()
    form.requestSubmit()
  }

  #beforeFrameRender(event) {
    if (event.target != this.element) return

    const newFrame = event.detail.newFrame
    const enteringForm = newFrame?.querySelector("[data-composer-form]")
    const onPicker = !this.element.querySelector("[data-composer-form]")

    if (enteringForm && onPicker) {
      stashes.set(this.element, this.element.innerHTML)
    }

    event.detail.render = (currentFrame, newFrame) => {
      const transition = swapWithViewTransition(() => {
        currentFrame.innerHTML = newFrame.innerHTML
      })

      const cleanup = () => this.#bindForm()

      if (transition) transition.finished.then(cleanup)
      else cleanup()
    }
  }

  #frameLoad(event) {
    if (event.target != this.element) return

    this.#bindForm()
  }

  // The composer <-> picker/list view transition is intentionally one-way:
  // entering the composer morphs the trigger into the type pill, but
  // leaving it (e.g. the full-page composer's "Back" link) should not play
  // that morph in reverse. Clearing the name right before the click's Drive
  // visit starts means this document has nothing to pair with the shared
  // name on the destination, so the browser just fades instead of morphing.
  skipReturnTransition() {
    document.querySelectorAll("[data-composer-transition-type]").forEach((element) => {
      element.style.viewTransitionName = "none"
    })
  }

  cancel(event) {
    event.preventDefault()

    const dialog = this.element.closest("dialog")
    if (dialog?.open && !dialog.classList.contains("bullet-composer--mobile-dialog")) {
      dialog.close()
      return
    }

    const frame = this.#isFrame ? this.element : this.element.closest("turbo-frame")
    if (frame && tryCancelFrame(frame)) return
  }

  dismiss() {
    const frame = this.#isFrame ? this.element : this.element.closest("turbo-frame")
    if (frame) restorePicker(frame)
  }

  #inlineSubmitKeydown(event) {
    if (event.key != "Enter") return
    if (event.defaultPrevented) return
    if (event.isComposing) return
    if (event.metaKey || event.ctrlKey || event.altKey) return

    const form = this.#form
    if (!form) return

    const editor = form.querySelector('lexxy-editor[preset="inline"]')
    if (!editor?.contains(event.target)) return

    event.preventDefault()
    event.stopPropagation()

    if (event.shiftKey) {
      form.requestSubmit(form.querySelector('button[name="another"]'))
    } else {
      form.requestSubmit()
    }
  }
}
