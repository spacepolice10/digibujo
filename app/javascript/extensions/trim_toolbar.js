import { Extension } from "lexxy"

export class TrimToolbarExtension extends Extension {
  get enabled() {
    return this.editorElement.preset == "note"
  }

  initializeToolbar(toolbar) {
    toolbar.querySelector('button[name="image"]')?.remove()
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

    this.editorElement.append(toolbar)
  }
}
