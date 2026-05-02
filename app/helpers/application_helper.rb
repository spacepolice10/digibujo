module ApplicationHelper
  def bullet_rich_text_preview_trix(bullet, max_chars: nil)
    body = bullet.content.body.to_s
    if body.empty?
      return "".html_safe
    end

    tag.div class: "trix-content" do
      max_chars.present? ? HtmlTruncation.truncate_html(body, max_chars).html_safe : body.html_safe
    end
  end
end
