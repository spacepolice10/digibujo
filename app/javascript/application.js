// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails";
import "controllers";
import * as ActiveStorage from "@rails/activestorage";

ActiveStorage.start();

import * as Lexxy from "lexxy";
import { TrimToolbarExtension } from "extensions/trim_toolbar";

Lexxy.configure({
  global: {
    extensions: [TrimToolbarExtension],
  },
  inline: {
    attachments: true,
    toolbar: false,
    multiLine: true,
    richText: true,
    markdown: true,
  },
  note: {
    attachments: true,
    toolbar: { upload: "file" },
    multiLine: true,
    richText: true,
    markdown: true,
  },
});
