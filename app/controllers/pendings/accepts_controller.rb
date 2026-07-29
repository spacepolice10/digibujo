# frozen_string_literal: true

module Pendings
  class AcceptsController < ApplicationController
    before_action :set_bullet

    def create
      @bullet.accept_from_pending!
      @bullet.reload

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to pending_path, notice: 'Added to today' }
      end
    rescue ArgumentError, ActiveRecord::RecordInvalid => e
      message = e.is_a?(ActiveRecord::RecordInvalid) ? e.record.errors.full_messages.to_sentence : e.message
      respond_to do |format|
        format.turbo_stream do
          @failed_message = message
          render :create, status: :unprocessable_entity
        end
        format.html { redirect_to pending_path, alert: message }
      end
    end

    private

    def set_bullet
      @bullet = Current.user.bullets.find(params[:bullet_id])
    end
  end
end
