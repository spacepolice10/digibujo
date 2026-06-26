# frozen_string_literal: true

module Search::TermBuilder
  extend self

  def build(query)
    terms = normalize(query)
    return if terms.empty?

    terms.map { |term| "\"#{escape(term)}\"*" }.join(' AND ')
  end

  def normalize(query)
    query.to_s.downcase.gsub(/[^\p{L}\p{N}\s"]/u, ' ').split(/\s+/).grep(/\S/)
  end

  private

  def escape(term)
    term.delete('"')
  end
end
