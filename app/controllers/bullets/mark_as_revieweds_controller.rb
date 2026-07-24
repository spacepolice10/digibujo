# frozen_string_literal: true

module Bullets
  class MarkAsReviewedsController < ApplicationController
    include PrepareBullets

    def create
      @review_to = params[:to].present? ? params[:to].to_date : Date.yesterday
      @review_from = params[:from].present? ? params[:from].to_date : @review_to - 6.days

      bullets = bullets_to_mark

      Bullet.transaction do
        bullets.lock.find_each(&:mark_as_reviewed!)
      end

      redirect_to review_path(from: @review_from.iso8601, to: @review_to.iso8601)
    end

    private

    def review_bullets
      Current.user.bullets.in_review(@review_from..@review_to).order(created_at: :asc)
    end

    def bullets_to_mark
      if params[:bullet_ids].present?
        bullet_ids = prepare_bullet_list_from(params[:bullet_ids])
        raise ActiveRecord::RecordNotFound if bullet_ids.empty?

        scope = review_bullets.where(id: bullet_ids)
        raise ActiveRecord::RecordNotFound if scope.count != bullet_ids.size

        scope
      else
        review_bullets
      end
    end
  end
end
