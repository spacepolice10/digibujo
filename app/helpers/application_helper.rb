# frozen_string_literal: true

module ApplicationHelper
  def current_user
    Current.user
  end

  def mobile_variant?
    request.variant.include?(:mobile)
  end

  def back_link_to(url = home_path, **options, &block)
    data = (options[:data] || {}).dup
    data[:controller] = [data[:controller], 'navigation'].compact_blank.join(' ')
    data[:action] = [data[:action], 'click->navigation#back'].compact_blank.join(' ')

    link_to(url, options.merge(data: data), &block)
  end

  # Serve a resized representation instead of the original blob.
  def represent_image_tag(blob, variant: :display, **options)
    image_tag blob.representation(ImageVariant[variant]), **options
  end
end
