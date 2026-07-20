# frozen_string_literal: true

class ReviewsController < ApplicationController
  include PrepareBullets

  def show
    @review_to = params[:to].present? ? params[:to].to_date : Date.current
    @review_from = params[:from].present? ? params[:from].to_date : @review_to - 6.days

    scoped = review_bullets.includes(:bulletable)
    @bullets = set_page_and_extract_portion_from(scoped, per_page: [15, 30, 50])
    @amount_in_review = scoped.count
  end

  private

  def review_bullets
    Current.user.bullets.in_review(@review_from..@review_to).order(created_at: :asc)
  end
end
