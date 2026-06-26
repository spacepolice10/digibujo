# frozen_string_literal: true

class Bullet
  class Composer
    class << self
      def type_options
        Bullet.bulletable_types.map do |type|
          config = type.constantize.composer_config
          {
            type: type,
            name: config[:name],
            hint: config[:hint],
            icon: config[:icon].to_s,
            modifier: config[:modifier],
            marker_styles: config[:marker_styles],
            actiontext_preset: config[:actiontext_preset],
            accepts_editor_attachments: config[:accepts_editor_attachments],
            submit_on_enter: config[:submit_on_enter],
            submit_on_command_return: config[:submit_on_command_return],
            close_composer_on_submit: config[:close_composer_on_submit],
            hotkey: config[:hotkey]
          }
        end
      end

      def form_partial_path(type_name)
        type_name.to_s.constantize.composer_config[:form_partial]
      end
    end
  end
end
