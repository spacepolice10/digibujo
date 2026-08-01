# frozen_string_literal: true

class ReviewsController < ApplicationController
  include PrepareBullets

  def show
    @review_to = params[:to].present? ? params[:to].to_date : Date.yesterday
    @review_from = params[:from].present? ? params[:from].to_date : @review_to - 6.days

    scoped = review_bullets.includes(:bulletable)
    @bullets = set_page_and_extract_portion_from(scoped, per_page: [15, 30, 50])
    @amount_in_review = scoped.count
    @previous_date = previous_page_date
  end

  private

  def review_bullets
    Current.user.bullets.in_review(@review_from..@review_to).order(:pops_on, :created_at)
  end

  # Page 2+ may start mid-day; keep the prior page's last pops_on so the divider
  # does not repeat a day that already closed on the previous page.
  def previous_page_date
    return if @page.first? || @page.records.empty?

    first = @page.records.first
    previous = review_bullets.where(
      '(pops_on < ?) OR (pops_on = ? AND created_at < ?)',
      first.pops_on, first.pops_on, first.created_at
    ).last
    previous&.pops_on
  end
end
