# frozen_string_literal: true

module Iconable
  extend ActiveSupport::Concern

  ICON_MAPPINGS = {
    'pencil' => 'pencil',
    'circle-check' => 'circle-check',
    'calendar' => 'calendar',
    'file' => 'file',
    'book' => 'book',
    'menu' => 'menu',
    'pin' => 'pin',
    'archive' => 'archive',
    'paperclip' => 'paperclip',
    'arrow-up' => 'arrow-up'
  }.freeze

  EMOJI_ICONS = %w[
    folder briefcase house books lightbulb heart target memo art
    cooking airplane muscle cart music camera money calendar
  ].freeze

  included do
    validates :icon, inclusion: { in: ICON_MAPPINGS.keys + EMOJI_ICONS }, allow_nil: true
  end

  def icon_variable
    ICON_MAPPINGS[icon]
  end

  def icon_mask
    key = icon.presence || 'tag'
    "var(--icon-#{key})"
  end

  def emoji_icon?
    EMOJI_ICONS.include?(icon)
  end

  def icon_path
    "emoji/#{icon}.svg" if emoji_icon?
  end
end
