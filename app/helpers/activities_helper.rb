# frozen_string_literal: true

module ActivitiesHelper
  def activity_sentence(activity, relative: false, linked: true)
    parts = [sentence(activity, linked: linked)]
    parts << "#{time_ago_in_words(activity.created_at)} ago" if relative
    safe_join(parts, ', ')
  end

  private

  def sentence(activity, linked:)
    subject = activity_link(activity.subject, linked: linked, name: activity.subject_name)

    case activity.action
    when 'destroyed'
      safe_join(['Deleted ', subject])
    when 'archived'
      safe_join(['Archived ', subject])
    when 'unarchived'
      safe_join(['Unarchived ', subject])
    when 'created'
      safe_join(['Created ', subject])
    when 'updated'
      safe_join(['Updated ', subject])
    when 'pinned'
      safe_join(['Pinned ', subject])
    when 'unpinned'
      safe_join(['Unpinned ', subject])
    when 'completed'
      safe_join(['Completed ', subject])
    when 'uncompleted'
      safe_join(['Uncompleted ', subject])
    when 'collected'
      bucket_name = activity.metadata['bucket_name'].presence ||
                     activity.destination_bucket&.name ||
                     'a collection'
      safe_join([
        'Moved ', subject, ' into ',
        activity_link(activity.destination_bucket, linked: linked, name: bucket_name)
      ])
    when 'rescheduled'
      rescheduled_sentence(activity, subject, linked: linked)
    when 'project_mentioned'
      safe_join(['Mentioned project in ', subject])
    when 'project_unmentioned'
      safe_join(['Removed project from ', subject])
    else
      safe_join([activity.action.humanize, ' — ', subject])
    end
  end

  def rescheduled_sentence(activity, subject, linked:)
    from = activity_link(activity.from_date, linked: linked)
    to = activity_link(activity.to_date, linked: linked)

    if from && to
      safe_join(['Moved ', subject, ' from ', from, ' to ', to])
    elsif to
      safe_join(['Scheduled ', subject, ' for ', to])
    else
      safe_join(['Parked ', subject, ' for sometime'])
    end
  end

  def activity_link(target, linked:, name: nil)
    case target
    when Date
      formatted = target.strftime('%a, %b %-d')
      return formatted unless linked

      link_to(formatted, daylog_path(date: target.iso8601), class: 'activity--subject-name')
    when nil
      name
    else
      label = name.presence || target.try(:name) || 'Unknown'
      return label unless linked
      return label if target.is_a?(Archive)

      link_to(label, polymorphic_path(target), class: 'activity--subject-name')
    end
  end
end
