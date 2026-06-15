import { Extension } from "lexxy"

const URL_REGEX = /^https?:\/\/\S+$/i

function isCode(text) {
  if (!text.includes("\n")) return false
  const lines = text.split("\n")
  if (lines.length < 2) return false

  const hasIndentation = lines.some(line => /^[ \t]/.test(line))
  const hasCodePatterns = /[{([=<>+\-*\/%&|^~!:;]/.test(text) ||
    /\b(function|const|let|var|def|class|import|export|if|for|while|return)\b/i.test(text) ||
    /=>/.test(text)
  return hasIndentation || hasCodePatterns
}

function escapeHtml(text) {
  const div = document.createElement("div")
  div.textContent = text
  return div.innerHTML
}

function tryReadClipboardText() {
  if (!navigator.clipboard?.readText) return null
  return navigator.clipboard.readText().catch(() => null)
}

export class InlinePasteExtension extends Extension {
  get lexicalExtension() {
    return {
      name: "lexxy/inline-paste",
      register: (editor) => {
        const rootElement = editor.getRootElement()
        if (!rootElement) return () => {}

        const handler = (event) => {
          if (event.inputType !== "insertFromPaste" && event.inputType !== "insertFromPasteAsQuotation") return
          if (this.editorElement.getAttribute("preset") !== "inline") return

          event.preventDefault()
          event.stopImmediatePropagation()

          tryReadClipboardText().then(text => {
            if (text && text.trim()) {
              this.insertContent(text)
            }
          })
        }

        rootElement.addEventListener("beforeinput", handler, true)
        return () => rootElement.removeEventListener("beforeinput", handler, true)
      }
    }
  }

  insertContent(text) {
    text = text.trim()
    if (!text) return

    const contents = this.editorElement.contents

    if (URL_REGEX.test(text)) {
      contents.createLink(text)
    } else if (isCode(text)) {
      const html = `<pre><code>${escapeHtml(text)}</code></pre>`
      contents.insertHtml(html, { tag: "paste" })
    } else {
      const paragraphs = text.split("\n")
        .filter(line => line.trim())
        .map(line => `<p>${escapeHtml(line)}</p>`)
        .join("")
      if (paragraphs) {
        contents.insertHtml(paragraphs, { tag: "paste" })
      }
    }
  }
}
