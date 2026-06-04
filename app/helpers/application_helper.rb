# frozen_string_literal: true

module ApplicationHelper
  def bucket_icon_mask(bucket)
    key = bucket&.icon.presence || "tag"
    "var(--icon-#{key})"
  end

  def bucket_link_attributes(record)
    data = { turbo_frame: "_top" }
    data[:bucket_colour] = record.colour if record.colour.present?
    { data: data }
  end

  def bucket_list_item_partial(bucket)
    bucketable = bucket.bucketable
    case bucketable
    when Project
      { partial: "projects/project", locals: { project: bucketable } }
    when Collection
      { partial: "collections/collection", locals: { collection: bucketable } }
    end
  end

end
