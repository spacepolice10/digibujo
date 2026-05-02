class Bullets::ContextsController < ApplicationController
  SEARCH_LIMIT = 50
  RESULT_LIMIT = 10

  def index
    bullets = base_scope
    bullets = bullets.select { |bullet| matches_query?(bullet) } if query.present?

    render json: {
      bullets: bullets.first(RESULT_LIMIT).map { |bullet| serialize_bullet(bullet) }
    }
  end

  private

  def base_scope
    scope = Current.user.bullets.includes(:bulletable).with_rich_text_content.order(created_at: :desc).limit(SEARCH_LIMIT)
    return scope unless excluded_id.present?

    scope.where.not(id: excluded_id)
  end

  def serialize_bullet(bullet)
    {
      id: bullet.id,
      name: bullet.bulletable.name,
      type: bullet.bulletable_type.downcase,
      icon: bullet.icon
    }
  end

  def query
    @query ||= params[:q].to_s.strip.downcase
  end

  def excluded_id
    @excluded_id ||= params[:exclude_id].presence
  end

  def matches_query?(bullet)
    searchable_text(bullet).include?(query)
  end

  def searchable_text(bullet)
    [
      bullet.id,
      bullet.bulletable.name,
      bullet.content.to_plain_text
    ].join(" ").downcase
  end
end
