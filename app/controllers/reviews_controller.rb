# frozen_string_literal: true

class ReviewsController < ApplicationController
  include PaginatedRecords, PrepareBullets

  before_action :set_review_period, only: %i[show migrate]

  def show
    scoped = review_bullets.includes(:bulletable)
    @bullets = set_page_and_extract_portion_from(scoped, per_page: [15, 30, 50])
    @amount_in_review = scoped.count

    @week_days = (@review_to..(@review_to + 6.days)).to_a
    @week_bullets_by_date = week_bullets_by_date
    @schedule_tomorrow = @review_to + 1.day

    @collections_q = params[:q].to_s.strip.presence
    collections = Current.user.active_collections.matching_bucket_name(@collections_q)
    @collections, @collections_page = paginated_portion_from(collections, page_param: :collections_page,
                                                                          per_page: [8, 16, 24])
  end

  def migrate
    @bullets = review_bullets_to_migrate.to_a

    Bullet.transaction do
      Current.user.bullets.where(id: @bullets.map(&:id)).lock.find_each(&:acknowledge_migration!)
    end

    @remaining_in_review = review_bullets.count

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to review_path(from: @review_from.iso8601, to: @review_to.iso8601) }
    end
  end

  private

  def review_bullets
    Current.user.bullets
           .where(bucket_id: nil, migrated_at: nil, pops_on: @review_from..@review_to)
           .active
           .order(created_at: :asc)
  end

  def set_review_period
    @review_to = params[:to].present? ? params[:to].to_date : Date.current
    @review_from = params[:from].present? ? params[:from].to_date : @review_to - 6.days
    @review_from, @review_to = @review_to, @review_from if @review_from > @review_to
  end

  def review_bullets_to_migrate
    scope = review_bullets

    if params[:bullet_ids].present?
      bullet_ids = prepare_bullet_list_from(params[:bullet_ids])
      raise ActiveRecord::RecordNotFound if bullet_ids.empty?

      bullets = scope.where(id: bullet_ids)
      raise ActiveRecord::RecordNotFound if bullets.count != bullet_ids.size

      bullets
    else
      scope
    end
  end

  def week_bullets_by_date
    Current.user.bullets
           .where(pops_on: @week_days)
           .active
           .order(created_at: :asc)
           .includes(:bulletable)
           .group_by(&:pops_on)
  end
end
