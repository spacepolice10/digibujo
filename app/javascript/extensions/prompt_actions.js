import { Extension } from "lexxy"

const MENU_ITEM_SELECTOR = ".lexxy-prompt-menu__item"
const SELECT_KEYS = new Set(["Enter", "Tab", " "])

function commandFromListItem(listItem) {
  if (!listItem || listItem.classList.contains("lexxy-prompt-menu__item--empty")) return null

  return listItem.querySelector("[data-action]")
}

function selectedListItem(editorElement) {
  return Array.from(editorElement.querySelectorAll(MENU_ITEM_SELECTOR))
    .find((item) => item.hasAttribute("aria-selected")) ?? null
}

function findActivePrompt(editorElement) {
  let best = null
  let bestIndex = -1
  const contents = editorElement.contents
  const editor = editorElement.editor

  for (const prompt of editorElement.querySelectorAll("lexxy-prompt")) {
    const trigger = prompt.getAttribute("trigger")
    if (!trigger || !contents.containsTextBackUntil(trigger)) continue

    let lastIndex = -1
    editor.getEditorState().read(() => {
      const { node, offset } = editorElement.selection.selectedNodeWithOffset()
      if (!node?.getTextContent) return

      const textBeforeCursor = node.getTextContent().slice(0, offset)
      lastIndex = textBeforeCursor.lastIndexOf(trigger)
    })

    if (lastIndex > bestIndex) {
      bestIndex = lastIndex
      best = { prompt, trigger, filter: contents.textBackUntil(trigger) }
    }
  }

  return best
}

function removeActiveTrigger(editorElement) {
  const active = findActivePrompt(editorElement)
  if (!active) return

  const stringToReplace = `${active.trigger}${active.filter}`

  editorElement.editor.update(() => {
    editorElement.contents.replaceTextBackUntil(stringToReplace, [])
  })
}

function closePopover(editorElement) {
  editorElement.dispatchEvent(new KeyboardEvent("keydown", {
    key: "Escape",
    bubbles: true,
    cancelable: true,
  }))
}

function controllerElementFor(element, identifier) {
  let current = element

  while (current) {
    const controllers = (current.getAttribute("data-controller") || "").split(/\s+/).filter(Boolean)
    if (controllers.includes(identifier)) return current

    current = current.parentElement
  }

  return null
}

function invokeDataAction(element) {
  const descriptor = element.getAttribute("data-action")
  if (!descriptor) return false

  const actionPart = descriptor.includes("->") ? descriptor.split("->").pop() : descriptor
  const [identifier, methodName] = actionPart.split("#")
  if (!identifier || !methodName) return false

  const scope = controllerElementFor(element, identifier)
  const application = window.Stimulus
  if (!scope || !application) return false

  const controller = application.getControllerForElementAndIdentifier(scope, identifier)
  if (!controller || typeof controller[methodName] != "function") return false

  controller[methodName]({ currentTarget: element })
  return true
}

function runPromptCommand(editorElement, listItem) {
  const command = commandFromListItem(listItem)
  if (!command) return false

  removeActiveTrigger(editorElement)
  closePopover(editorElement)
  return invokeDataAction(command)
}

export class PromptActionExtension extends Extension {
  get enabled() {
    return this.editorElement.preset == "inline"
  }

  get lexicalExtension() {
    const editorElement = this.editorElement

    return {
      name: "digibujo/prompt-actions",
      register(editor) {
        const handleClick = (event) => {
          if (!editorElement.hasOpenPrompt) return

          const listItem = event.target.closest(MENU_ITEM_SELECTOR)
          if (!commandFromListItem(listItem)) return

          event.preventDefault()
          event.stopImmediatePropagation()
          runPromptCommand(editorElement, listItem)
        }

        const handleKeydown = (event) => {
          if (!editorElement.hasOpenPrompt) return
          if (!SELECT_KEYS.has(event.key)) return

          const listItem = selectedListItem(editorElement)
          if (!commandFromListItem(listItem)) return

          event.preventDefault()
          event.stopImmediatePropagation()
          runPromptCommand(editorElement, listItem)
        }

        editorElement.addEventListener("click", handleClick, true)
        editorElement.addEventListener("keydown", handleKeydown, true)

        return () => {
          editorElement.removeEventListener("click", handleClick, true)
          editorElement.removeEventListener("keydown", handleKeydown, true)
        }
      },
    }
  }
}
