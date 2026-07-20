# frozen_string_literal: true

module Migratable
  extend ActiveSupport::Concern

  def migrated?
    migrated_at.present?
  end

  def collected_migration?
    migrated? && last_migration['action'] == 'collected'
  end

  def postponed_migration?
    migrated? && last_migration['action'].in?(%w[postponed popped])
  end

  def popped_migration?
    postponed_migration?
  end

  def mark_as_reviewed!
    mark_migration!(action: 'acknowledged', pops_on: pops_on)
  end

  def migrate_to!(bucket:, pops_on: nil, action: nil)
    raise ArgumentError, 'bucket is required' if bucket.blank?

    from_bucket = self.bucket
    from_pops_on = self.pops_on
    resolved_pops_on = pops_on_for_destination(bucket, pops_on)

    update!(bucket: bucket, pops_on: resolved_pops_on)

    stamp_action = action.presence || migration_action_for(bucket)
    mark_migration!(
      action: stamp_action,
      from_bucket_id: from_bucket&.id,
      from_bucketable_type: from_bucket&.bucketable_type,
      to_bucket_id: bucket.id,
      bucket_id: bucket.id,
      bucket_name: bucket.name,
      bucketable_type: bucket.bucketable_type,
      from_pops_on: from_pops_on,
      to_pops_on: resolved_pops_on
    )
  end

  def mark_migration!(action:, **details)
    payload = { 'action' => action }.merge(
      details.transform_keys(&:to_s).transform_values { |value| serialize_migration_value(value) }
    )
    update!(migrated_at: Time.current, last_migration: payload)
    record_activity!(action, metadata: payload)
  end

  def migration_hint
    return unless migrated?

    case last_migration['action']
    when 'postponed', 'popped' then migration_postponed_hint
    when 'collected' then migration_collected_hint
    when 'completed' then migration_completed_hint
    when 'archived' then migration_archived_hint
    when 'acknowledged' then migration_acknowledged_hint
    when 'migrated' then migration_generic_hint
    else
      'Moved from another log or collection.'
    end
  end

  private

  def pops_on_for_destination(bucket, pops_on)
    case bucket.bucketable_type
    when 'Daylog'
      pops_on.presence || Date.current
    when 'Monthlylog'
      pops_on
    when 'Future'
      return nil if pops_on.blank?

      pops_on.to_date.beginning_of_month
    when 'Collection'
      nil
    else
      pops_on
    end
  end

  def migration_action_for(bucket)
    case bucket.bucketable_type
    when 'Collection' then 'collected'
    when 'Daylog' then 'postponed'
    else 'migrated'
    end
  end

  def migration_postponed_hint
    from = migration_date_name(last_migration['from_pops_on'])
    to = migration_date_name(pops_on)

    if from && to
      "Rescheduled from #{from} to #{to}."
    elsif to
      "Scheduled for #{to}."
    elsif bucket&.bucketable_type == 'Future'
      'Parked for sometime.'
    else
      'Rescheduled to another day.'
    end
  end

  def migration_collected_hint
    bucket_name = last_migration['bucket_name'].presence || bucket&.name || 'a collection'
    "Moved into #{bucket_name}."
  end

  def migration_completed_hint
    date = migration_date_name(pops_on)
    date ? "Completed on #{date}." : 'Completed.'
  end

  def migration_archived_hint
    date = migration_date_name(pops_on)
    date ? "Removed from #{date}." : 'Removed from the daily log.'
  end

  def migration_acknowledged_hint
    date = migration_date_name(pops_on)
    date ? "Kept on #{date}." : 'No changes during review.'
  end

  def migration_generic_hint
    name = last_migration['bucket_name'].presence || bucket&.name
    name ? "Migrated to #{name}." : 'Migrated.'
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
