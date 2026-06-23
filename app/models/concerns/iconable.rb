# frozen_string_literal: true

module Iconable
  extend ActiveSupport::Concern

  ICON_MAPPINGS = %w[
    folder briefcase house books lightbulb heart target memo art
    cooking airplane muscle cart music camera money calendar
  ].freeze

  included do
    validates :icon, inclusion: { in: ICON_MAPPINGS }, allow_nil: true
  end

  def icon_mask
    key = icon.presence || 'tag'
    "var(--icon-#{key})"
  end

  def icon_path
    "emoji/#{icon}.svg" if icon.present?
  end
end
