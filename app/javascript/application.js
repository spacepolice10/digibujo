// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails";
import "controllers";

import * as Lexxy from "lexxy";
import { InlinePastingExtension } from "extensions/inline_pasting";
import { PromptActionExtension } from "extensions/prompt_actions";

Lexxy.configure({
  global: {
    extensions: [InlinePastingExtension, PromptActionExtension],
  },
  inline: {
    attachments: true,
    toolbar: false,
    multiLine: false,
    richText: true,
    markdown: false,
  },
  expand: {
    attachments: true,
    toolbar: true,
    multiLine: true,
    richText: true,
    markdown: true,
  },
});
