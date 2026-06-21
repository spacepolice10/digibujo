# frozen_string_literal: true

module Migratable
  extend ActiveSupport::Concern

  MIGRATION_KINDS = %w[scheduled collected completed discarded].freeze

  ACTION_BY_KIND = {
    "scheduled" => "popped",
    "collected" => "collected",
    "completed" => "completed",
    "discarded" => "archived"
  }.freeze

  def migrated?
    migrated_at.present?
  end

  def stamp_migration!(kind:, **details)
    payload = { "kind" => kind }.merge(
      details.transform_keys(&:to_s).transform_values { |value| serialize_migration_value(value) }
    )
    update!(migrated_at: Time.current, last_migration: payload)
    record_activity!(ACTION_BY_KIND.fetch(kind), metadata: payload)
  end

  private

  def serialize_migration_value(value)
    case value
    when Date, Time, ActiveSupport::TimeWithZone then value.iso8601
    else value
    end
  end
end
