# frozen_string_literal: true

module Bullets
  class PostponesController < ApplicationController
    include PrepareBullets

    before_action :prepare_bullets, only: %i[new create]

    def new
      daylog_bucket = Current.user.daylog.bucket
      monthlylog_bucket = Current.user.monthlylogs.covering(Date.current).take.bucket
      future_bucket = Current.user.futures.covering(Date.current).take.bucket

      @postpone_options = [
        { id: :asap,          icon: 'arrow-up',        name: 'ASAP',
          pops_on: Date.current,                           bucket_id: daylog_bucket.id },
        { id: :tomorrow,      icon: 'arrow-right',     name: 'Tomorrow',
          pops_on: Date.current + 1.day,                   bucket_id: monthlylog_bucket.id },
        { id: :next_monday,   icon: 'calendar-repeat', name: 'Next week',
          pops_on: Date.current.next_occurring(:monday),   bucket_id: monthlylog_bucket.id },
        { id: :next_weekends, icon: 'calendar-repeat', name: 'Next weekend',
          pops_on: Date.current.next_occurring(:saturday), bucket_id: monthlylog_bucket.id },
        { id: :monthlylog,    icon: 'calendar',        name: 'This month',   pops_on: nil,
          bucket_id: monthlylog_bucket.id },
        { id: :future,        icon: 'calendar',        name: 'Sometime',     pops_on: nil, bucket_id: future_bucket.id }
      ]
      @manual_bucket = monthlylog_bucket
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
