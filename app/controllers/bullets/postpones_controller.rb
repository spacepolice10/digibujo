# frozen_string_literal: true

module Bullets
  class PostponesController < ApplicationController
    include PrepareBullets

    before_action :prepare_bullets, only: %i[new create]

    def new
      @asap = Date.current
      @tomorrow = Date.current + 1.day
      @next_monday = Date.current.next_occurring(:monday)
      @next_weekends = Date.current.next_occurring(:saturday)
      @daylog_bucket = Onboarding.ensure_daylog_bucket!(Current.user)
      @daylog_buckets = {
        asap: @daylog_bucket,
        tomorrow: @daylog_bucket,
        next_monday: @daylog_bucket,
        next_weekends: @daylog_bucket
      }
      @future = Current.user.futures.covering(Date.current).take
      @monthlylog = Current.user.monthlylogs.find_by(
        period_from: Date.current.beginning_of_month
      )
    end

    def create
      destination = Current.user.buckets.active.find(params.require(:bucket_id))
      pops_on = parse_pops_on

      Bullet.transaction do
        @bullets.lock.find_each { |bullet| bullet.postpone!(bucket: destination, pops_on: pops_on) }
      end
      @bullets.each(&:reload)
      return head :no_content if postpone_drop_request?

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_back fallback_location: daylog_path }
      end
    rescue ActionController::ParameterMissing, ActiveRecord::RecordNotFound
      @failed_bullet = @bullets&.first
      respond_to do |format|
        format.turbo_stream { render :create, status: :unprocessable_entity }
        format.html do
          redirect_back fallback_location: daylog_path, alert: 'Invalid destination'
        end
      end
    rescue ArgumentError
      @failed_bullet = @bullets.first
      respond_to do |format|
        format.turbo_stream { render :create, status: :unprocessable_entity }
        format.html do
          redirect_back fallback_location: daylog_path, alert: 'Invalid date'
        end
      end
    rescue ActiveRecord::RecordInvalid => e
      @failed_bullet = e.record
      respond_to do |format|
        format.turbo_stream { render :create, status: :unprocessable_entity }
        format.html do
          redirect_back fallback_location: daylog_path,
                        alert: e.record.errors.full_messages.to_sentence
        end
      end
    end

    private

    def parse_pops_on
      raw = params[:pops_on].to_s
      return nil if raw.blank?

      Date.iso8601(raw)
    end

    def postpone_drop_request?
      request.headers['X-Requested-With'].in?(%w[pops-drop review-pops-drop])
    end
  end
end
