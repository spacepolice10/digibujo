# frozen_string_literal: true

module BulletsHelper
  BULLET_TYPE_CONFIG = {
    'Task' => {
      icon: 'square',
      modifier: 'task',
      hotkey: 'Shift+T',
      colour: 'var(--model-color-2)',
      placeholder: 'What needs to be done?',
      description: 'Something to do',
      hotkey_action: 'keydown.shift+t@document->hotkey#click'
    },
    'Note' => {
      icon: 'text',
      modifier: 'note',
      hotkey: 'Shift+N',
      colour: 'var(--model-color-4)',
      placeholder: 'Write it down…',
      description: 'Thoughts, ideas, files, markdown, anything',
      hotkey_action: 'keydown.shift+n@document->hotkey#click'
    },
    'Event' => {
      icon: 'circle',
      modifier: 'event',
      hotkey: 'Shift+E',
      colour: 'var(--model-color-5)',
      placeholder: "What's in agenda?",
      description: 'Appointments and dates',
      hotkey_action: 'keydown.shift+e@document->hotkey#click'
    },
    'Voice' => {
      icon: 'microphone',
      modifier: 'voice',
      hotkey: 'Shift+V',
      colour: 'var(--model-color-3)',
      placeholder: 'Caption your voice, guitar playing or cat meowing…',
      description: 'Quick audio memo',
      hotkey_action: 'keydown.shift+v@document->hotkey#click'
    }
  }.freeze

  # Voice is driven by the mic button, not the type picker.
  COMPOSER_VARIANTS = %w[Note Task Event].freeze
  DAYLOG_COMPOSER_VARIANTS = %w[Note Task Event Voice].freeze

  def bullet_type_config(type_name)
    BULLET_TYPE_CONFIG.fetch(type_name) { raise ArgumentError, "Unknown bullet type: #{type_name}" }
  end
end
