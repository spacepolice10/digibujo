# frozen_string_literal: true

module ApplicationHelper
  include LogPathHelper
  def bucket_icon_mask(bucket)
    key = bucket&.icon.presence || "tag"
    "var(--icon-#{key})"
  end

  def bucket_link_attributes(record)
    data = { turbo_frame: "_top" }
    data[:bucket_colour] = record.colour if record.colour.present?
    { data: data }
  end

  def hint_anchor_style(anchor_name)
    "anchor-name: #{anchor_name}"
  end
end
