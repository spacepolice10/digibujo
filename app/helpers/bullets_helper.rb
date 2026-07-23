# frozen_string_literal: true

module BulletsHelper
  BULLET_TYPE_CONFIG = {
    'Task' => {
      icon: 'square',
      modifier: 'task',
      hotkey: 'Shift+T',
      colour: 'var(--model-color-2)',
      hotkey_action: 'keydown.shift+t@document->hotkey#click'
    },
    'Note' => {
      icon: 'text',
      modifier: 'note',
      hotkey: 'Shift+N',
      colour: 'var(--model-color-4)',
      hotkey_action: 'keydown.shift+n@document->hotkey#click'
    },
    'Event' => {
      icon: 'circle',
      modifier: 'event',
      hotkey: 'Shift+E',
      colour: 'var(--model-color-5)',
      hotkey_action: 'keydown.shift+e@document->hotkey#click'
    },
    'Voice' => {
      icon: 'microphone',
      modifier: 'voice',
      hotkey: 'Shift+V',
      colour: 'var(--model-color-3)',
      hotkey_action: 'keydown.shift+v@document->hotkey#click'
    }
  }.freeze

  def create_bullet_buttons(composer_id:, bucket_id:, pops_on:, bulletable_type:)
    safe_join(
      Array(bulletable_type).map do |type_name|
        create_bullet_button(
          type_name: type_name.to_s,
          composer_id: composer_id,
          bucket_id: bucket_id,
          pops_on: pops_on
        )
      end
    )
  end

  private

  def create_bullet_button(type_name:, composer_id:, bucket_id:, pops_on:)
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
              turbo_frame: composer_id,
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
