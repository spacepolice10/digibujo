# frozen_string_literal: true

module Migratable
  extend ActiveSupport::Concern

  MIGRATION_ACTIONS = %w[collected rescheduled].freeze

  def migrated?
    migrated_at.present?
  end

  def collected_migration?
    migrated? && last_migration['action'] == 'collected'
  end

  def rescheduled_migration?
    migrated? && last_migration['action'] == 'rescheduled'
  end

  def mark_as_reviewed!
    update!(migrated_at: Time.current, last_migration: {})
  end

  def migrate_to!(bucket:, pops_on:, action:)
    raise ArgumentError, 'bucket is required' if bucket.blank?
    raise ArgumentError, "action must be one of #{MIGRATION_ACTIONS.join(', ')}" unless action.in?(MIGRATION_ACTIONS)

    from_bucket = self.bucket
    from_pops_on = self.pops_on

    update!(bucket: bucket, pops_on: pops_on)

    mark_migration!(
      action: action,
      from_bucket_id: from_bucket&.id,
      bucket_id: bucket.id,
      bucket_name: bucket.name,
      from_pops_on: from_pops_on,
      to_pops_on: pops_on
    )
  end

  def mark_migration!(action:, **details)
    raise ArgumentError, "action must be one of #{MIGRATION_ACTIONS.join(', ')}" unless action.in?(MIGRATION_ACTIONS)

    payload = { 'action' => action }.merge(
      details.transform_keys(&:to_s).transform_values { |value| serialize_migration_value(value) }
    )
    update!(migrated_at: Time.current, last_migration: payload)
    record_activity!(action, metadata: payload)
  end

  def migration_hint
    return unless migrated?

    case last_migration['action']
    when 'rescheduled' then rescheduled_hint
    when 'collected' then collected_hint
    end
  end

  private

  def rescheduled_hint
    from = migration_date_name(last_migration['from_pops_on'])
    to = migration_date_name(pops_on)

    if from && to
      "Rescheduled from #{from} to #{to}."
    elsif to
      "Scheduled for #{to}."
    elsif bucket&.bucketable_type == 'Future'
      'Parked for sometime.'
    elsif (name = last_migration['bucket_name'].presence || bucket&.name)
      "Rescheduled to #{name}."
    else
      'Rescheduled.'
    end
  end

  def collected_hint
    bucket_name = last_migration['bucket_name'].presence || bucket&.name || 'a collection'
    "Moved into #{bucket_name}."
  end

  def migration_date_name(date)
    return if date.blank?

    date.to_date.strftime('%a, %b %-d')
  end

  def serialize_migration_value(value)
    case value
    when Date then value.iso8601
    when Time, ActiveSupport::TimeWithZone then value.iso8601
    else value
    end
  end
end
