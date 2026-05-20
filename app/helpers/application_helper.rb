# frozen_string_literal: true

module ApplicationHelper
  def bucket_icon_mask(bucket)
    key = bucket&.icon.presence || "tag"
    "var(--icon-#{key})"
  end

  def bucket_link_style(record)
    return {} unless record.colour.present?

    { style: "background: #{record.colour_bg_variable}" }
  end
end
