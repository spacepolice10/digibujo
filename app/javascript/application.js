// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails";
import "controllers";

import * as Lexxy from "lexxy";

Lexxy.configure({
  inline: {
    attachments: true,
    toolbar: false,
    multiLine: false,
    richText: true,
    markdown: false,
  },
  note: {
    attachments: true,
    toolbar: true,
    multiLine: true,
    richText: true,
    markdown: true,
  },
});
