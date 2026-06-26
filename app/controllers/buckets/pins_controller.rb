# frozen_string_literal: true

module Buckets
  class PinsController < ApplicationController
    include PreparePinned

    before_action :set_bucket

    def create
      @bucket.pin!
      @bucket.record_activity!('pinned', metadata: { 'bucketable_type' => @bucket.bucketable_type })
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_back fallback_location: home_path }
      end
    end

    def destroy
      @bucket.unpin!
      @bucket.record_activity!('unpinned', metadata: { 'bucketable_type' => @bucket.bucketable_type })
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_back fallback_location: home_path }
      end
    end

    private

    def set_bucket
      @bucket = Current.user.buckets.find(params.require(:bucket_id))
    end

    helper_method :pinned_buckets
  end
end
