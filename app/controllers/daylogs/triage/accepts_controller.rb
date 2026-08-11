# frozen_string_literal: true

module Daylogs
  module Triage
    # Moves one or more current triage entries into today's daylog.
    class AcceptsController < ApplicationController
      def create
        @bullets = migrate_to_today(triage_bullets)
        successful_response
      rescue ActiveRecord::RecordInvalid => e
        @failed_message = e.record.errors.full_messages.to_sentence
        failed_response
      end

      private

      def triage_bullets
        requested_ids = requested_bullet_ids
        bullets = Daylog::Triage.new(Current.user).bullets.select { |bullet| requested_ids.include?(bullet.id.to_s) }
        raise ActiveRecord::RecordNotFound if requested_ids.empty? || bullets.size != requested_ids.size

        bullets
      end

      def requested_bullet_ids
        params[:bullet_ids].to_s.split(',').reject(&:blank?).uniq
      end

      def migrate_to_today(bullets)
        Bullet.transaction do
          bullets.each { |bullet| bullet.postpone!(bucket: Current.user.daylog.bucket, pops_on: Date.current) }
        end
        bullets.each(&:reload)
      end

      def successful_response
        respond_to do |format|
          format.turbo_stream
          format.html { redirect_to daylog_triage_path, notice: acceptance_message }
        end
      end

      def failed_response
        respond_to do |format|
          format.turbo_stream { render :create, status: :unprocessable_entity }
          format.html { redirect_to daylog_triage_path, alert: @failed_message }
        end
      end

      def acceptance_message
        @bullets.one? ? 'Added to today' : "#{@bullets.size} bullets added to today"
      end
    end
  end
end
