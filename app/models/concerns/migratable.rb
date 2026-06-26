# frozen_string_literal: true

module Migratable
  extend ActiveSupport::Concern

  def migrated?
    migrated_at.present?
  end

  def acknowledge_migration!
    mark_migration!(action: 'acknowledged', pops_on: pops_on)
  end

  def mark_migration!(action:, **details)
    payload = { 'action' => action }.merge(details.transform_keys(&:to_s))
    update!(migrated_at: Time.current, last_migration: payload)
    record_activity!(action, metadata: payload)
  end
end
