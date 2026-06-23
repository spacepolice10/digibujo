# frozen_string_literal: true

class Note < ApplicationRecord
  include Bulletable

  composer label: 'Note',
           hint: 'Reference or log entry',
           icon: :'line-dashed',
           modifier: 'note',
           marker_styles: 'bullet--note-marker',
           form_partial: 'bullets/composer/note'

  enum :mood, { positive: 0, negative: 1, inspired: 2, frustrated: 3 }

  def temporal?      = false
  def completable?   = false
  def marker_styles  = 'bullet--note-marker'

  def excerpt
    text = bullet.body.to_plain_text
    if text.length > 400
      text.truncate(400) || 'Untitled'
    else
      bullet.body
    end
  end

  def mood_marker
    case mood&.to_sym
    when :positive   then '😊'
    when :negative   then '😞'
    when :inspired   then '✨'
    when :frustrated then '😣'
    end
  end
end
