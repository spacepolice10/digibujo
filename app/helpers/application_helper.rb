module ApplicationHelper
  def card_rich_text_preview_trix(card, max_chars: Note::RICH_TEXT_PREVIEW_MAX_CHARS)
    return "".html_safe if max_chars <= 0

    body = card.content.body.to_s
    if body.empty?
      return "".html_safe
    end

    tag.div class: "trix-content" do
      HtmlTruncation.truncate_html(body, max_chars).html_safe
    end
  end
end
