// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails";
import "controllers";

import * as Lexxy from "lexxy";

Lexxy.configure({
  inline: {
    toolbar: false,
    multiline: false,
    richText: true,
    markdown: true,
  },
});
