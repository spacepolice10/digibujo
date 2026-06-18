import { Extension } from "lexxy"

const BARE_URL = /^https?:\/\/\S+$/i

function normalizePaste(text) {
  return text.replace(/\s+/g, " ").trim()
}

function escapeHtml(text) {
  const div = document.createElement("div")
  div.textContent = text
  return div.innerHTML
}

function insertPlainText(rootElement, contents, text) {
  rootElement.focus()

  if (document.execCommand("insertText", false, text)) return

  contents.insertHtml(`<p>${escapeHtml(text)}</p>`, { tag: "paste" })
}

export class InlinePastingExtension extends Extension {
  get enabled() {
    return this.editorElement.preset == "inline"
  }

  get lexicalExtension() {
    const editorElement = this.editorElement

    return {
      name: "digibujo/inline-pasting",
      register(editor) {
        return editor.registerRootListener((rootElement) => {
          if (!rootElement) return

          const handlePaste = (event) => {
            const clipboardData = event.clipboardData || event.dataTransfer
            if (!clipboardData) return
            if (clipboardData.files?.length > 0) return

            const text = normalizePaste(clipboardData.getData("text/plain") ?? "")
            if (!text) return

            event.preventDefault()
            event.stopImmediatePropagation()

            const contents = editorElement.contents

            if (BARE_URL.test(text)) {
              if (contents.hasSelectedText()) {
                contents.createLinkWithSelectedText(text)
              } else {
                contents.createLink(text)
              }
            } else {
              insertPlainText(rootElement, contents, text)
            }
          }

          rootElement.addEventListener("paste", handlePaste, true)

          return () => rootElement.removeEventListener("paste", handlePaste, true)
        })
      },
    }
  }
}
