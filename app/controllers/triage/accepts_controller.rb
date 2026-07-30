# frozen_string_literal: true

module Triage
  class AcceptsController < ApplicationController
    before_action :set_bullet

    def create
      @bullet.postpone!(bucket: Current.user.daylog.bucket, pops_on: Date.current)
      @bullet.reload

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to triage_path, notice: 'Added to today' }
      end
    rescue ActiveRecord::RecordInvalid => e
      message = e.record.errors.full_messages.to_sentence
      respond_to do |format|
        format.turbo_stream do
          @failed_message = message
          render :create, status: :unprocessable_entity
        end
        format.html { redirect_to triage_path, alert: message }
      end
    end

    private

    def set_bullet
      @bullet = Current.user.bullets.find(params[:bullet_id])
    end
  end
end
