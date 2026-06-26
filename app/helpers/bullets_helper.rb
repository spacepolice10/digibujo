# frozen_string_literal: true

module BulletsHelper
  def migration_hint(bullet)
    return unless bullet.migrated?

    case bullet.last_migration['action']
    when 'popped' then migration_popped_hint(bullet)
    when 'collected' then migration_collected_hint(bullet)
    when 'completed' then migration_completed_hint(bullet)
    when 'archived' then migration_archived_hint(bullet)
    when 'acknowledged' then migration_acknowledged_hint(bullet)
    else
      'Migrated — moved from another log or collection.'
    end
  end

  private

  def migration_popped_hint(bullet)
    from = migration_date_name(bullet.last_migration['from_pops_on'])
    to = migration_date_name(bullet.pops_on)

    if from && to
      "Moved — rescheduled from #{from} to #{to}."
    elsif to
      "Scheduled — set for #{to}."
    else
      'Moved — rescheduled to another day.'
    end
  end

  def migration_collected_hint(bullet)
    bucket_name = bullet.last_migration['bucket_name'].presence || bullet.bucket&.name || 'a collection'
    "Collected — moved into #{bucket_name}."
  end

  def migration_completed_hint(bullet)
    date = migration_date_name(bullet.pops_on)
    date ? "Completed on #{date}." : 'Completed.'
  end

  def migration_archived_hint(bullet)
    date = migration_date_name(bullet.pops_on)
    date ? "Archived — removed from #{date}." : 'Archived — removed from the daily log.'
  end

  def migration_acknowledged_hint(bullet)
    date = migration_date_name(bullet.pops_on)
    date ? "Reviewed — kept on #{date}." : 'Reviewed — no changes during review.'
  end

  def migration_date_name(date)
    return if date.blank?

    date.to_date.strftime('%a, %b %-d')
  end
end
