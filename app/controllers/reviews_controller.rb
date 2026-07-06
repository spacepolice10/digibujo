# frozen_string_literal: true

class ReviewsController < ApplicationController
  include PaginatedRecords, PrepareBullets

  before_action :set_review_period, only: :show

  def show
    scoped = review_bullets.includes(:bulletable)
    @bullets = set_page_and_extract_portion_from(scoped, per_page: [15, 30, 50])
    @amount_in_review = scoped.count

    @week_days = (@review_to..(@review_to + 6.days)).to_a
    @week_bullets_by_date = week_bullets_by_date

    @collections_q = params[:q].to_s.strip.presence
    collections = Current.user.active_collections.matching_bucket_name(@collections_q)
    @collections, @collections_page = paginated_portion_from(collections, page_param: :collections_page,
                                                                          per_page: [8, 16, 24])
  end

  private

  def review_bullets
    Current.user.bullets.where(pops_on: @review_from..@review_to).where(migrated_at: nil).order(created_at: :asc)
  end

  def set_review_period
    @review_to = params[:to].present? ? params[:to].to_date : Date.current
    @review_from = params[:from].present? ? params[:from].to_date : @review_to - 6.days
    @review_from, @review_to = @review_to, @review_from if @review_from > @review_to
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
