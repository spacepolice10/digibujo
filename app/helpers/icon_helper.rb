module IconHelper
  def icon_tag(icon, options = {})
    key = icon.presence || Iconable::DEFAULT_ICON
    styles = [ "--icon-mask: var(--icon-#{key})" ]
    styles << "color: #{options[:colour]}" if options[:colour].present?

    content_tag(:i, '', class: class_names('icon', options[:class]), style: styles.join('; '),
                        aria: { hidden: true })
  end
end
