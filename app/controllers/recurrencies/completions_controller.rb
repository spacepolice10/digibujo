# frozen_string_literal: true

module Recurrencies
  class CompletionsController < ApplicationController
    COMPLETION_DOM_KEYS = %w[header inline cell].freeze

    before_action :set_recurrency
    before_action :set_date
    before_action :set_dom_key

    def create
      unless @recurrency.scheduled_on?(@date)
        return respond_unprocessable
      end

      @completion = @recurrency.completions.find_or_initialize_by(date: @date)
      @completion.completed_at = Time.current
      @completion.save!

      respond_to_completion
    end

    def destroy
      @completion = @recurrency.completions.find_by(date: @date)
      @completion&.destroy!

      respond_to_completion
    end

    private

    def set_recurrency
      @recurrency = Current.user.recurrencies.find(params[:recurrency_id])
    end

    def set_date
      @date = Date.iso8601(params[:date].to_s)
    rescue ArgumentError
      head :unprocessable_entity
    end

    def respond_to_completion
      @tracker = RecurrencyTracker.new(user: Current.user, from: @date, to: @date)

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_back fallback_location: recurrencies_path }
        format.any { head :no_content }
      end
    end

    def set_dom_key
      @dom_key = params[:dom_key].presence_in(COMPLETION_DOM_KEYS) || "header"
    end

    def respond_unprocessable
      respond_to do |format|
        format.turbo_stream { head :unprocessable_entity }
        format.html { redirect_back fallback_location: recurrencies_path, alert: "Cannot mark this day" }
        format.any { head :unprocessable_entity }
      end
    end
  end
end
