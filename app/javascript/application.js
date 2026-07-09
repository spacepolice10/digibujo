// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails";
import "controllers";
import * as ActiveStorage from "@rails/activestorage";

ActiveStorage.start();

import * as Lexxy from "lexxy";

/**
 * Configure Lexxy editors for 'inline' and 'note' presets.
 * autofocus, placeholder, etc. are HTML attributes on <lexxy-editor> — see bullets/_form.html.erb.
 *
 * Reference: https://github.com/basecamp/lexxy?tab=readme-ov-file#lexxyconfigurepresets
 */
Lexxy.configure({
  global: {

  },
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
