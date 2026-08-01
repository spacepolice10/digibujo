# frozen_string_literal: true

module Monthlylogs
  class BulletsController < ApplicationController
    def index
      @monthlylog = Current.user.monthlylogs.find(params[:monthlylog_id])
      @date = parsed_date(params[:date])
      return if performed?

      scoped = @monthlylog.bullets.active.where(pops_on: @date).includes(:bulletable)

      if params[:before].present?
        cursor = scoped.find_by(id: params[:before])
        return head :no_content unless cursor

        @bullets = scoped.page_before(cursor)
        return head :no_content if @bullets.empty?

        render :page, layout: false
      else
        @bullets = scoped.last_page
        @more_bullets = @bullets.size == Bullet::Pageable::PAGE_SIZE
      end
    end

    private

    def parsed_date(date)
      return if date.blank?

      Date.iso8601(date.to_s)
    rescue Date::Error, ArgumentError
      head :not_found
      nil
    end
  end
end
