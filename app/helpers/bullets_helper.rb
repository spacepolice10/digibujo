# frozen_string_literal: true

module BulletsHelper
  BULLET_TYPE_CONFIG = {
    'Task' => {
      icon: 'square',
      modifier: 'task',
      hotkey: 'Shift+T',
      colour: 'var(--model-color-2)',
      placeholder: 'What need to be done?',
      description: 'Something to do',
      hotkey_action: 'keydown.shift+t@document->hotkey#click'
    },
    'Note' => {
      icon: 'text',
      modifier: 'note',
      hotkey: 'Shift+N',
      colour: 'var(--model-color-4)',
      placeholder: 'Write it down…',
      description: 'Thoughts, ideas, anything',
      hotkey_action: 'keydown.shift+n@document->hotkey#click'
    },
    'Event' => {
      icon: 'circle',
      modifier: 'event',
      hotkey: 'Shift+E',
      colour: 'var(--model-color-5)',
      placeholder: 'Write down appointments or notable events…',
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
  COMPOSER_TYPES = %w[Note Task Event].freeze

  def create_bullet_buttons(bucket_id:, pops_on:, bulletable_type:)
    safe_join(
      Array(bulletable_type).map do |type_name|
        create_bullet_button(
          type_name: type_name.to_s,
          bucket_id: bucket_id,
          pops_on: pops_on
        )
      end
    )
  end

  def bullet_type_config(type_name)
    BULLET_TYPE_CONFIG.fetch(type_name) { raise ArgumentError, "Unknown bullet type: #{type_name}" }
  end

  def bullet_composer_return_path(bullet)
    bucketable = bullet.bucket&.bucketable
    case bucketable
    when Daylog
      daylog_path(date: (bullet.pops_on || Date.current).iso8601)
    when Collection
      collection_path(bucketable)
    when Monthlylog
      monthlylog_path(bucketable)
    when Future
      future_path(bucketable)
    else
      daylog_path
    end
  end

  private

  def create_bullet_button(type_name:, bucket_id:, pops_on:)
    config = BULLET_TYPE_CONFIG.fetch(type_name) do
      raise ArgumentError, "Unknown bullet type: #{type_name}"
    end

    link_to new_bullet_path(
      pops_on: pops_on,
      bucket_id: bucket_id,
      bulletable_type: type_name
    ),
            class: [
              'bullets-form--create-button',
              "bullets-form--create-button--#{config[:modifier]}",
              ('hotkey-hint' if config[:hotkey])
            ].compact,
            data: {
              bullet_type: config[:modifier],
              composer_expand: true,
              turbo_frame: '_top',
              controller: ('hotkey' if config[:hotkey]),
              hotkey: config[:hotkey],
              action: config[:hotkey_action]
            }.compact,
            aria: { label: "Add #{type_name}", keyshortcuts: config[:hotkey] }.compact do
      safe_join([
                  icon_tag(config[:icon], style: "color: #{config[:colour]};", class: 'button--icon'),
                  type_name
                ])
    end
  end
end
