# frozen_string_literal: true

# Wraps search hits in already-rendered HTML. Only text nodes are touched, so
# tags, attributes, and embeds stay as they were.
class Search::Highlight
  CLASS_NAME = 'search--hit'

  class << self
    def call(html, query)
      words = Search::TermBuilder.terms(query)
      return html if words.empty?

      pattern = pattern_for(words)
      fragment = Loofah.html5_fragment(html.to_s)
      changed = false

      fragment.xpath('.//text()').to_a.each do |node|
        next if node.content.blank?
        next unless node.content.match?(pattern)
        next if node.ancestors.any? { |ancestor| ancestor.element? && ancestor.name.in?(%w[mark script style]) }

        node.replace(marked(node.content, pattern))
        changed = true
      end

      changed ? fragment.to_html.html_safe : html
    end

    private

    def pattern_for(words)
      alternation = words.sort_by { |word| -word.length }.map { |word| Regexp.escape(word) }.join('|')
      /(?<![\p{L}\p{N}])(?:#{alternation})[\p{L}\p{N}]*/i
    end

    def marked(text, pattern)
      cursor = 0
      pieces = +''

      text.scan(pattern) do
        match = Regexp.last_match
        pieces << ERB::Util.html_escape(text[cursor...match.begin(0)])
        pieces << %(<mark class="#{CLASS_NAME}">#{ERB::Util.html_escape(match[0])}</mark>)
        cursor = match.end(0)
      end

      pieces << ERB::Util.html_escape(text[cursor..])
      pieces
    end
  end
end
