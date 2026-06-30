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

  def migration_hint
    return unless migrated?

    case last_migration['action']
    when 'popped' then migration_popped_hint
    when 'collected' then migration_collected_hint
    when 'completed' then migration_completed_hint
    when 'archived' then migration_archived_hint
    when 'acknowledged' then migration_acknowledged_hint
    else
      'Migrated — moved from another log or collection.'
    end
  end

  private

  def migration_popped_hint
    from = migration_date_name(last_migration['from_pops_on'])
    to = migration_date_name(pops_on)

    if from && to
      "Moved — rescheduled from #{from} to #{to}."
    elsif to
      "Scheduled — set for #{to}."
    else
      'Moved — rescheduled to another day.'
    end
  end

  def migration_collected_hint
    bucket_name = last_migration['bucket_name'].presence || bucket&.name || 'a collection'
    "Collected — moved into #{bucket_name}."
  end

  def migration_completed_hint
    date = migration_date_name(pops_on)
    date ? "Completed on #{date}." : 'Completed.'
  end

  def migration_archived_hint
    date = migration_date_name(pops_on)
    date ? "Archived — removed from #{date}." : 'Archived — removed from the daily log.'
  end

  def migration_acknowledged_hint
    date = migration_date_name(pops_on)
    date ? "Reviewed — kept on #{date}." : 'Reviewed — no changes during review.'
  end

  def migration_date_name(date)
    return if date.blank?

    date.to_date.strftime('%a, %b %-d')
  end
end
