# frozen_string_literal: true

module Bullets
  class ComposersController < ApplicationController
    def new
      @bucket = Current.user.buckets.find(params[:bucket_id])
      @pops_on = parsed_date(params[:pops_on])
      @composer_id = params.require(:composer_id)
      @frame_id = "#{@composer_id}_frame"
      @return_to = url_from(params[:return_to]) || home_path
      @allowed_bulletable_variants = allowed_bulletable_variants
    end

    private

    def parsed_date(value)
      return if value.blank?

      Date.iso8601(value.to_s)
    rescue Date::Error, ArgumentError
      raise ActiveRecord::RecordNotFound
    end

    def allowed_bulletable_variants
      case @bucket.bucketable_type
      when 'Monthlylog'
        @pops_on ? %w[Task Event] : %w[Task Note]
      when 'Future', 'Pending'
        %w[Task Note]
      else
        %w[Task Note Event Voice]
      end
    end
  end
end
