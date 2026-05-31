# frozen_string_literal: true

module Buckets
  class PickerChoicesController < ApplicationController
    before_action :set_target!

    def create
      @bucket = find_bucket
      @field_name = params[:field_name].presence || "bullet[bucket_id]"

      respond_to do |format|
        format.turbo_stream
      end
    end

    private

    def set_target!
      @target = params[:target].to_s.presence
      head :bad_request unless @target
    end

    def find_bucket
      bucket_id = params[:bucket_id].to_s.strip
      return nil if bucket_id.blank?

      Current.user.buckets.find(bucket_id)
    end
  end
end
