module BulletHelper
  def bullet_type_label(bullet)
    bullet.bulletable_type
  end

  def bullet_preview_trix(bullet)
    body = bullet.content.body.to_s
    return "".html_safe if body.empty?

    document = Nokogiri::HTML.fragment(body)
    container = document.at_css(".trix-content") || document
    blocks = container.element_children
    first_block = blocks.first&.to_html || ""
    more_blocks = blocks.size > 1

    content = tag.div(class: "trix-content") { first_block.html_safe }

    if more_blocks
      link_to bullet_path(bullet), data: { turbo_frame: "_top" }, class: "bullet-preview--link" do
        safe_join([content, bullet_preview_expand_icon])
      end
    else
      content
    end
  end

  private

  def bullet_preview_expand_icon
    tag.i class: "icon bullet-preview--expand",
          style: "--icon-mask: var(--icon-expand)",
          aria: { hidden: true }
  end
end
