# frozen_string_literal: true

module Pendings
  class DiscardsController < ApplicationController
    before_action :set_bullet

    def create
      @bullet.archive!
      @bullet.reload

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to pending_path, notice: 'Discarded' }
      end
    rescue ActiveRecord::RecordInvalid => e
      respond_to do |format|
        format.turbo_stream do
          @failed_message = e.record.errors.full_messages.to_sentence
          render :create, status: :unprocessable_entity
        end
        format.html { redirect_to pending_path, alert: e.record.errors.full_messages.to_sentence }
      end
    end

    private

    def set_bullet
      @bullet = Current.user.bullets.find(params[:bullet_id])
    end
  end
end
