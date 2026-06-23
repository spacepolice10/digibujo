# frozen_string_literal: true

class Bullet
  class Composer
    DEFAULT_TYPE = 'Note'

    ACTION_OPTIONS = [
      { value: 'attachment', icon: 'paperclip', label: 'Attachment', hint: 'Upload files' },
      { value: 'expand', icon: 'expand', label: 'Expand', hint: 'Code, files, markdown' }
    ].freeze

    class << self
      def default_type = DEFAULT_TYPE

      def type_options
        Bullet.bulletable_types.map do |type|
          config = type.constantize.composer_config
          {
            value: type,
            label: config[:label],
            hint: config[:hint],
            icon: config[:icon].to_s,
            modifier: config[:modifier],
            marker_styles: config[:marker_styles]
          }
        end
      end

      def action_options = ACTION_OPTIONS

      def config_for(type_name)
        type_name.to_s.constantize.composer_config
      end

      def form_partial_path(type_name)
        config_for(type_name)[:form_partial]
      end

      def form_fields?(type_name)
        form_partial_path(type_name).present?
      end
    end
  end
end
