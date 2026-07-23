module IconHelper
  def icon_tag(icon, options = {})
    icon_name = icon.presence || Iconable::DEFAULT_ICON
    content_tag(
      :span,
      content_tag(:i, '', class: 'icon', style: "--icon-mask: var(--icon-#{icon_name});",
                          aria: { hidden: true }),
      class: class_names('icon-wrap', options[:class]),
      style: options[:style]
    ).html_safe
  end
end
