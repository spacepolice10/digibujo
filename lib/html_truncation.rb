# frozen_string_literal: true

require "nokogiri"

# Truncates a fragment of HTML to a text character budget. Works on text
# nodes in document order: tags that open before the cut stay; content after
# the cut (including the rest of a split text node) is removed.
module HtmlTruncation
  OMISSION = "…"

  class << self
    def truncate_html(html, max_chars, omission: OMISSION)
      return +"".freeze if max_chars <= 0
      s = html.to_s
      return s if s.empty?

      doc = Nokogiri::HTML5.fragment(s)
      texts = doc.xpath(".//text()").to_a
      return doc.to_html if text_length(texts) <= max_chars

      remaining = max_chars
      last_i = texts.length - 1

      texts.each_with_index do |node, i|
        t = node.text
        l = t.length
        next if l == 0

        if remaining > l
          remaining -= l
        elsif remaining == l
          if i < last_i
            remove_following_siblings_in_tree(node)
          end
          return doc.to_html
        else
          node.content = t[0, remaining] + omission
          remove_following_siblings_in_tree(node)
          return doc.to_html
        end
      end

      doc.to_html
    end

    private

    def fragment_node?(node)
      node.is_a?(Nokogiri::HTML::DocumentFragment) ||
        node.class.name.to_s.include?("DocumentFragment")
    end

    def text_length(texts)
      texts.sum { |n| n.text.length }
    end

    def remove_following_siblings_in_tree(node)
      current = node
      loop do
        while (sib = current.next)
          sib.remove
        end
        parent = current.parent
        return if parent.nil?
        if fragment_node?(parent)
          return
        end

        current = parent
      end
    end
  end
end
