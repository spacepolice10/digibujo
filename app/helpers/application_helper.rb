# frozen_string_literal: true

module ApplicationHelper
  def current_user
    Current.user
  end

  def mobile_variant?
    request.variant.include?(:mobile)
  end

  def back_link_to(url = search_path, **options, &block)
    data = (options[:data] || {}).dup
    data[:role] = 'button'
    data[:controller] = [data[:controller], 'navigation'].compact_blank.join(' ')
    data[:action] = [data[:action], 'click->navigation#back'].compact_blank.join(' ')

    link_to(url, options.merge(data: data), &block)
  end

  def highlight_search(html, query)
    Search::Highlight.call(html, query)
  end

  def search_results_count(size)
    label = size == Search::GlobalRequest::LIMIT ? "#{size}+" : size
    "#{label} #{'result'.pluralize(size)}"
  end

  def time_period(time = Time.now)
    case time.hour
    when 5...12 then 'morning'
    when 12...17 then 'afternoon'
    when 17...21 then 'evening'
    else 'night'
    end
  end
end
