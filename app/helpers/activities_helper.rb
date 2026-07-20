# frozen_string_literal: true

module ActivitiesHelper
  def activity_sentence(activity, relative: false, linked: true)
    parts = [sentence_for(activity, linked: linked)]
    parts << "#{time_ago_in_words(activity.created_at)} ago" if relative
    safe_join(parts, ', ')
  end

  private

  def sentence_for(activity, linked:)
    subject = activity_subject_link(activity, linked: linked)

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
      safe_join(['Moved ', subject, ' into ', activity_bucket_link(activity, linked: linked)])
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
    from = activity_day_link(activity.from_date, linked: linked)
    to = activity_day_link(activity.to_date, linked: linked)

    if from && to
      safe_join(['Moved ', subject, ' from ', from, ' to ', to])
    elsif to
      safe_join(['Scheduled ', subject, ' for ', to])
    else
      safe_join(['Parked ', subject, ' for sometime'])
    end
  end

  def activity_subject_link(activity, linked:)
    name = activity.subject_name
    return name unless linked && activity.subject_present?
    return name if activity.subject_type == 'Archive'

    link_to(name, polymorphic_path(activity.subject), class: 'activity--subject-name')
  end

  def activity_bucket_link(activity, linked:)
    name = activity.metadata['bucket_name'].presence || activity.destination_bucket&.name || 'a collection'
    bucket = activity.destination_bucket
    return name unless linked && bucket

    link_to(name, polymorphic_path(bucket), class: 'activity--subject-name')
  end

  def activity_day_link(date, linked:)
    return if date.blank?

    formatted = date.strftime('%a, %b %-d')
    return formatted unless linked

    link_to(formatted, daylog_path(date: date.iso8601), class: 'activity--subject-name')
  end
end
