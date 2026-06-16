# frozen_string_literal: true

# Adds a `settings` association to the including model and auto-creates a
# User::Settings row on create.
#
# rubocop:disable Style/ClassAndModuleChildren
module User::Configurable
  extend ActiveSupport::Concern

  included do
    has_one :settings, class_name: 'User::Settings', dependent: :destroy
    after_create :create_settings
  end

  # Returns the settings record, creating it on demand. Use this when you
  # need to read or write settings and cannot assume the row exists yet
  # (e.g. users created before settings were introduced).
  def settings!
    settings || create_settings!
  end
end
# rubocop:enable Style/ClassAndModuleChildren
