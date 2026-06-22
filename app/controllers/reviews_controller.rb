# frozen_string_literal: true

class ReviewsController < ApplicationController
  include UserCollections, PreparePinned

  COLLECTIONS_LIMIT = 8
  MOBILE_COLLECTS_LIMIT = 5
  DEFAULT_REVIEW_PERIOD_DAYS = 7

  def show
    @review_from, @review_to = review_dates_from_params
    return unless @review_from && @review_to

    assign_review_page_data
  end

  private

  def assign_review_page_data
    scoped = Current.user.bullets.in_review(from: @review_from, to: @review_to).includes(:bulletable)
    @bullets = set_page_and_extract_portion_from(scoped, per_page: [15, 30, 50])
    @amount_in_review = scoped.count

    @week_start = @review_to
    @week_days = (@week_start..(@week_start + 6.days)).to_a
    @collections = review_collections
    @show_collections_more = user_collections.count > COLLECTIONS_LIMIT
    @mobile_collections = @collections.first(MOBILE_COLLECTS_LIMIT)
    @week_bullets_by_date = week_bullets_by_date
    @schedule_tomorrow = @review_to + 1.day
  end

  def review_collections
    pinned = pinned_buckets.filter_map { |bucket| bucket.bucketable if bucket.bucketable.is_a?(Collection) }
    pinned_ids = pinned.map(&:id)
    remaining = COLLECTIONS_LIMIT - pinned.size
    rest = if remaining.positive?
             user_collections.where.not(collections: { id: pinned_ids }).limit(remaining).to_a
           else
             []
           end

    (pinned + rest).first(COLLECTIONS_LIMIT)
  end

  def week_bullets_by_date
    return {} if @week_days.empty?

    Current.user.bullets
             .where(pops_on: @week_days, archived: false)
             .chronological
             .includes(:bulletable)
             .group_by(&:pops_on)
  end

  def review_dates_from_params
    to = parse_review_date(params[:to]) || Date.current
    from = parse_review_date(params[:from]) || (to - (DEFAULT_REVIEW_PERIOD_DAYS - 1).days)
    from, to = to, from if from > to
    [from, to]
  rescue ArgumentError
    head :not_found
    [nil, nil]
  end

  def parse_review_date(value)
    return nil if value.blank?

    Date.iso8601(value.to_s)
  end
end
