// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails";
import "controllers";

import * as Lexxy from "lexxy";
import { InlinePastingExtension } from "extensions/inline_pasting";

Lexxy.configure({
  inline: {
    extensions: [InlinePastingExtension],
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
