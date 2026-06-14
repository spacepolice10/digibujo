# frozen_string_literal: true

Rails.application.config.to_prepare do
  helper = ActionText::ContentHelper

  helper.allowed_attributes = (
    helper.sanitizer.class.allowed_attributes +
    ActionText::Attachment::ATTRIBUTES +
    %w[data-turbo-frame data-turbo]
  ).uniq.freeze
end
