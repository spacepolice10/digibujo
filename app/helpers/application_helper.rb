# frozen_string_literal: true

module ApplicationHelper
  def current_user
    Current.user
  end

  def back_link_to(url = home_path, **options, &block)
    data = (options[:data] || {}).dup
    data[:controller] = [ data[:controller], "navigation" ].compact_blank.join(" ")
    data[:action] = [ data[:action], "click->navigation#back" ].compact_blank.join(" ")

    link_to(url, options.merge(data: data), &block)
  end
end
