// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails";
import "controllers";
import * as ActiveStorage from "@rails/activestorage";

ActiveStorage.start();

import * as Lexxy from "lexxy";
import { InlinePastingExtension } from "extensions/inline_pasting";
import { PromptActionExtension } from "extensions/prompt_actions";
import { TrimToolbarExtension } from "extensions/trim_toolbar";

/**
 * Configure Lexxy editors for 'inline' and 'note' presets.
 * autofocus, placeholder, etc. are HTML attributes on <lexxy-editor> — see bullets/composer/_action_text.html.erb.
 *
 * Reference: https://github.com/basecamp/lexxy?tab=readme-ov-file#lexxyconfigurepresets
 */
Lexxy.configure({
  global: {
    extensions: [PromptActionExtension, TrimToolbarExtension],
  },
  inline: {
    extensions: [InlinePastingExtension, PromptActionExtension],
    attachments: false,
    toolbar: false,
    multiLine: false,
    richText: true,
    markdown: false,
  },
  note: {
    extensions: [PromptActionExtension, TrimToolbarExtension],
    attachments: true,
    toolbar: true,
    multiLine: true,
    richText: true,
    markdown: true,
  },
});
