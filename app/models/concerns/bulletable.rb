# frozen_string_literal: true

module Bulletable
  extend ActiveSupport::Concern

  INLINE_EDITOR_DEFAULTS = {
    actiontext_preset: 'inline',
    editor_multiline: false,
    editor_placeholder: "What's on your mind?",
    editor_container_class: 'bullet-form-composer',
    accepts_editor_attachments: false,
    submit_on_enter: true,
    submit_on_command_return: false,
    close_composer_on_submit: false
  }.freeze

  included do
    has_one :bullet, as: :bulletable, dependent: :destroy
  end

  def temporal?                = false
  def completable?             = false
  def name                     = bullet.body.to_plain_text.strip.presence || 'Untitled'
  def excerpt                  = name
  def marker_icon              = :line_dashed
  def marker_styles            = 'bullet--note-marker'
  def completed?               = false
  def mood_marker              = nil
  def shows_marker?            = true
  def list_link_uses_excerpt?  = false
  def compact_list_name_class  = nil

  def actiontext_preset        = self.class.composer_config[:actiontext_preset]
  def editor_multiline?        = self.class.composer_config[:editor_multiline]
  def editor_placeholder       = self.class.composer_config[:editor_placeholder]
  def editor_container_class   = self.class.composer_config[:editor_container_class]
  def accepts_editor_attachments? = self.class.composer_config[:accepts_editor_attachments]
  def submit_on_enter? = self.class.composer_config[:submit_on_enter]
  def submit_on_command_return? = self.class.composer_config[:submit_on_command_return]
  def close_composer_on_submit? = self.class.composer_config[:close_composer_on_submit]

  module ClassMethods
    def composer(name:, hint:, icon:, modifier:, marker_styles:, form_partial: nil, hotkey: nil, **editor)
      config = composer_config
      config[:name] = name
      config[:hint] = hint
      config[:icon] = icon
      config[:modifier] = modifier
      config[:marker_styles] = marker_styles
      config[:form_partial] = form_partial
      config[:hotkey] = hotkey
      config.merge!(INLINE_EDITOR_DEFAULTS.merge(editor))
      config
    end

    def composer_config
      @composer_config ||= {
        name: to_s,
        hint: nil,
        icon: nil,
        modifier: nil,
        marker_styles: nil,
        form_partial: nil,
        hotkey: nil
      }.merge(INLINE_EDITOR_DEFAULTS)
    end

    def composer_type_fields? = composer_config[:form_partial].present?

    def composer_action_options
      return [] unless composer_config[:accepts_editor_attachments]

      [{ value: 'attachment', icon: 'paperclip', name: 'Attachment', hint: 'Upload files' }]
    end

    def permitted_bullet_attributes
      []
    end
  end
end
