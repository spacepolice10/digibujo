class SearchesController < ApplicationController
  def show
    @query = params[:q].to_s.strip
    @cards = set_page_and_extract_portion_from(search_scope, per_page: [5, 15, 30, 50])

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  private

  def search_scope
    scope = Current.user.cards.includes(:collection).timeline_chronological
    return scope if @query.blank?

    matching_ids = scope.select { |card| searchable_text(card).include?(normalized_query) }.map(&:id)
    scope.where(id: matching_ids)
  end

  def normalized_query
    @normalized_query ||= @query.downcase
  end

  def searchable_text(card)
    [
      card.content.to_plain_text,
      card.collection&.name
    ].compact.join(" ").downcase
  end
end
