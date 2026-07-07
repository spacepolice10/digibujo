# frozen_string_literal: true

module Bulletable
  extend ActiveSupport::Concern

  MENTION_ATTACHMENT_TYPES = %w[
    application/vnd.actiontext.project
    application/vnd.actiontext.person
  ].freeze

  COMPOSER_STIMULUS_ACTIONS = 'keydown.enter+meta->composer#submit keydown.enter+ctrl->composer#submit'

  included do
    has_one :bullet, as: :bulletable, dependent: :destroy, inverse_of: :bulletable

    has_rich_text :body
  end

  def temporal?        = false
  def completable?     = false
  def starts_date      = nil
  def ends_date        = nil
  def name             = body.to_plain_text.strip.presence || 'Untitled'
  def excerpt          = body.to_plain_text.strip.presence || 'Untitled'
  def marker_icon      = :line_dashed
  def completed?       = false
  def mood_marker      = nil

  def to_partial_body_path
    "#{self.class.model_name.route_key}/body"
  end

  def to_toolbar_path
    nil
  end

  def preset
    'inline'
  end

  def permitted_attachment_types
    MENTION_ATTACHMENT_TYPES
  end

  def editor_html_options
    types = permitted_attachment_types
    types ? { "permitted-attachment-types": types.to_json } : {}
  end

  def toolbar_id
    "toolbar-#{self.class.model_name.element}"
  end

  def focusing_on_render?
    true
  end

  def placeholder
    "What's on your mind?"
  end

  def stimulus_controller
    nil
  end

  def stimulus_actions
    COMPOSER_STIMULUS_ACTIONS
  end

  def data_attributes
    {}
  end

  module ClassMethods
    def permitted_bullet_attributes
      %i[]
    end
  end
end
