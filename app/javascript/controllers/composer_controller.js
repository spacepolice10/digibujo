import { Controller } from "@hotwired/stimulus"

const stashes = new Map()
let globalsAttached = false

const TRANSITION_PREFIX = "composer-type-"

function sharedElementName(type) {
  return type ? `${TRANSITION_PREFIX}${type}` : null
}

function labelSharedElement(container, type) {
  const name = sharedElementName(type)
  if (!name) return

  const pill = container.querySelector(`[data-composer-transition-type="${type}"]`)
  if (pill) pill.style.viewTransitionName = name
}

function labelPickerButton(container, type) {
  const name = sharedElementName(type)
  if (!name) return

  const button = container.querySelector(`.bullet--composer-create-button--${type}`)
  if (button) button.style.viewTransitionName = name
}

function clearSharedElements(container) {
  container.querySelectorAll("[data-composer-transition-type], .bullet--composer-create-button").forEach((element) => {
    element.style.viewTransitionName = ""
  })
}

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
  const content = stashes.get(frame.id)
  if (!content) return false

  const type = frame.querySelector("[data-composer-transition-type]")?.dataset.composerTransitionType
  if (type) labelSharedElement(frame, type)

  const transition = swapWithViewTransition(() => {
    frame.removeAttribute("src")
    frame.innerHTML = content
    if (type) labelPickerButton(frame, type)
  })

  const finish = () => {
    clearSharedElements(frame)
    frame.dispatchEvent(new CustomEvent("composer:rebind"))
    frame.querySelector("a, button")?.focus?.()
  }

  if (transition) transition.finished.then(finish)
  else finish()

  return true
}

function frameToCancel() {
  const candidates = []

  for (const frameId of stashes.keys()) {
    const frame = document.getElementById(frameId)
    if (!frame?.querySelector(".bullet-composer")) continue

    candidates.push(frame)
  }

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

  const form = frame.querySelector(".bullet-composer")
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
  if (!form?.classList?.contains("bullet-composer")) return

  const submitter = event.detail.formSubmission?.submitter
  if (submitter?.name == "another") return

  const frame = form.closest("turbo-frame")
  if (!frame || !stashes.has(frame.id)) return

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
    if (this.#isFrame) return this.element.querySelector(".bullet-composer")
    if (this.element.classList.contains("bullet-composer")) return this.element

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
    const enteringForm = newFrame?.querySelector(".bullet-composer")
    const onPicker = !this.element.querySelector(".bullet-composer")

    if (enteringForm && onPicker) {
      stashes.set(this.element.id, this.element.innerHTML)
    }

    const pendingType = this.pendingTransitionType
    const frame = this.element

    event.detail.render = (currentFrame, newFrame) => {
      const transition = swapWithViewTransition(() => {
        currentFrame.innerHTML = newFrame.innerHTML
        if (pendingType) labelSharedElement(currentFrame, pendingType)
      })

      const cleanup = () => {
        clearSharedElements(frame)
        this.pendingTransitionType = null
        this.#bindForm()
      }

      if (transition) transition.finished.then(cleanup)
      else cleanup()
    }
  }

  markTransition(event) {
    const type = event.currentTarget.dataset.composerTransitionType
    if (!type) return

    this.pendingTransitionType = type
    event.currentTarget.style.viewTransitionName = sharedElementName(type)
  }

  #frameLoad(event) {
    if (event.target != this.element) return

    this.#bindForm()
  }

  cancel(event) {
    event.preventDefault()
    tryCancelFrame(this.element)
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
