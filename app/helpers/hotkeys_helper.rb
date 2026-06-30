# frozen_string_literal: true

module HotkeysHelper
  def hotkey_click_action(*chords)
    chords.flatten.flat_map { |chord|
      chord.to_s.split(/\s+/).map { |binding|
        filter = binding.split("+").map { |key| key.strip.downcase }.join("+")
        "keydown.#{filter}@document->hotkey#click"
      }
    }.join(" ")
  end
end
