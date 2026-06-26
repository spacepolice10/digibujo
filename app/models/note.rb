# frozen_string_literal: true

class Note < ApplicationRecord
  include Bulletable

  composer name: 'Note',
           hint: 'Reference or log entry',
           icon: :'line-dashed',
           modifier: 'note',
           marker_styles: 'bullet--note-marker',
           hotkey: 'Shift+N',
           form_partial: 'notes/composer_fields',
           actiontext_preset: 'note',
           editor_multiline: true,
           editor_placeholder: 'Code, files, markdown…',
           editor_container_class: 'bullet-form-expand bullet-form-note-richtext',
           accepts_editor_attachments: true,
           submit_on_enter: false,
           submit_on_command_return: true

  enum :mood, { positive: 0, negative: 1, inspired: 2, frustrated: 3 }

  MOOD_MARKERS = {
    positive: '😊',
    negative: '😞',
    inspired: '✨',
    frustrated: '😣'
  }.freeze

  def self.permitted_bullet_attributes = %i[mood]

  def temporal?                = false
  def completable?             = false
  def starts_date              = nil
  def ends_date                = nil
  def marker_styles            = 'bullet--note-marker'
  def list_link_uses_excerpt?  = true

  def excerpt
    text = bullet.body.to_plain_text
    if text.length > 400
      text.truncate(400) || 'Untitled'
    else
      bullet.body
    end
  end

  def mood_marker
    MOOD_MARKERS[mood&.to_sym]
  end
end
