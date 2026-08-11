# frozen_string_literal: true

module Monthlylogs
  class BulletsController < ApplicationController
    before_action :set_monthlylog
    def index
      @date = parsed_date(params[:date])
      return if performed?

      scoped = @monthlylog.bullets.active.scheduled.includes(:bulletable)

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

    def new
      @bullet = Bullet.new
    end

    def create
      @bullet = Bullet.new(bullet_params)
      @bullet.save

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to monthlylog_path(@monthlylog), notice: 'Bullet created' }
      end
    end

    private

    def set_monthlylog
      @monthlylog = Current.user.monthlylogs.find(params[:monthlylog_id])
    end

    def bullet_params
      attributes = allowed_bulletable_entity.permitted_bullet_attributes

      if @bullet&.persisted?
        params.require(:bullet).permit(:body, bulletable_attributes: attributes)
      else
        params.require(:bullet).permit(%i[pops_on bulletable_type bucket_id body], bulletable_attributes: attributes)
      end
    end

    def allowed_bulletable_entity
      name = (@bullet&.bulletable_type || params.dig(:bullet, :bulletable_type)).to_s
      allowed = name.presence_in(Bullet.bulletable_types)
      raise ActionController::ParameterMissing, 'bulletable_type' unless allowed

      allowed.constantize
    end

    def parsed_date(date)
      return if date.blank?

      Date.iso8601(date.to_s)
    rescue Date::Error, ArgumentError
      head :not_found
      nil
    end
  end
end
