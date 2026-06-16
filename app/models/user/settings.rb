# frozen_string_literal: true

# Per-user settings. One row per user, created automatically.
#
# rubocop:disable Style/ClassAndModuleChildren
class User::Settings < ApplicationRecord
  SECTIONS = %w[logs projects collections spreads].freeze

  belongs_to :user

  def section_open?(key, default: true)
    return default unless SECTIONS.include?(key.to_s)

    public_send("#{key}_open?")
  end

  def set_section_open(key, value)
    public_send("#{key}_open=", value)
    save!
  end
end
# rubocop:enable Style/ClassAndModuleChildren
