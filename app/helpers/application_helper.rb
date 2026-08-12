# frozen_string_literal: true

module ApplicationHelper
  def current_user
    Current.user
  end

  def mobile_variant?
    request.variant.include?(:mobile)
  end

  def tabbar_visible?
    action_name == 'show' && controller_name.in?(%w[home daylogs]) ||
      action_name == 'index' && controller_name == 'activities'
  end

  def current_monthlylog_navigation_path
    monthlylog = Current.user.monthlylogs.covering(Date.current).first
    return current_monthlylog_path unless monthlylog

    monthlylog_path(monthlylog)
  end

  def current_futures_navigation_path
    future = Current.user.futures.covering(Date.current).first
    return current_future_path unless future

    future_path(future)
  end

  def back_link_to(url = home_path, **options, &block)
    data = (options[:data] || {}).dup
    data[:controller] = [data[:controller], 'navigation'].compact_blank.join(' ')
    data[:action] = [data[:action], 'click->navigation#back'].compact_blank.join(' ')

    link_to(url, options.merge(data: data), &block)
  end

  def time_period(time = Time.now)
    case time.hour
    when 5...12 then 'morning'
    when 12...17 then 'afternoon'
    when 17...21 then 'evening'
    else 'night'
    end
  end

  # Serve a resized representation instead of the original blob.
  # Width/height from analyzed metadata reserve layout space before the image loads.
  def represent_image_tag(blob, variant: :display, **options)
    image_tag blob.representation(ImageVariant[variant]),
              **representation_dimension_options(blob, variant:).merge(options)
  end

  private

  def representation_dimension_options(blob, variant:)
    width = blob.metadata['width'].presence&.to_i
    height = blob.metadata['height'].presence&.to_i
    return {} unless width&.positive? && height&.positive?

    if (limit = ImageVariant[variant][:resize_to_limit])
      max_w, max_h = limit
      scale = [max_w.to_f / width, max_h.to_f / height, 1.0].min
      width = (width * scale).round
      height = (height * scale).round
    end

    { width:, height: }
  end
end
