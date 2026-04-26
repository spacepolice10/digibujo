class Cards::ContextsController < ApplicationController
  SEARCH_LIMIT = 50
  RESULT_LIMIT = 10

  def index
    cards = base_scope
    cards = cards.select { |card| matches_query?(card) } if query.present?

    render json: {
      cards: cards.first(RESULT_LIMIT).map { |card| serialize_card(card) }
    }
  end

  private

  def base_scope
    scope = Current.user.cards.includes(:cardable).with_rich_text_content.order(created_at: :desc).limit(SEARCH_LIMIT)
    return scope unless excluded_id.present?

    scope.where.not(id: excluded_id)
  end

  def serialize_card(card)
    {
      id: card.id,
      name: card.cardable.name,
      type: card.cardable_type.downcase,
      icon: card.icon
    }
  end

  def query
    @query ||= params[:q].to_s.strip.downcase
  end

  def excluded_id
    @excluded_id ||= params[:exclude_id].presence
  end

  def matches_query?(card)
    searchable_text(card).include?(query)
  end

  def searchable_text(card)
    [
      card.cardable.name,
      card.content.to_plain_text
    ].join(" ").downcase
  end
end
