import { Extension } from "lexxy"

// Note-preset toolbar: drop controls Digibujo doesn't surface in the chat /
// note composers. Keep the toolbar in place: moving a connected
// <lexxy-toolbar> runs dispose() and kills its command handlers.
export class TrimToolbarExtension extends Extension {
  initializeToolbar(toolbar) {
    toolbar.querySelector('button[name="underline"]')?.remove()
    toolbar.querySelector('button[name="quote"]')?.remove()
    toolbar.querySelector('button[name="undo"]')?.remove()
    toolbar.querySelector('button[name="redo"]')?.remove()
    toolbar.querySelector("lexxy-link-dropdown")?.remove()
    toolbar.querySelector("lexxy-highlight-dropdown")?.remove()
    toolbar.querySelector("button[name='strikethrough']")?.remove()
    toolbar.querySelector("button[name='ordered-list']")?.remove()
    toolbar.querySelector("button[name='divider']")?.remove()
    toolbar.querySelector('button[name="format"]')?.closest("lexxy-toolbar-dropdown")?.remove()
    toolbar.querySelectorAll(".lexxy-editor__toolbar-group-end").forEach((button) => {
      button.classList.remove("lexxy-editor__toolbar-group-end")
    })
    toolbar.querySelectorAll(".lexxy-editor__toolbar-separator").forEach((el) => el.remove())
  }
}
