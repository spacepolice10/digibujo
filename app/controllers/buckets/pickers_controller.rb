# frozen_string_literal: true

module Buckets
  class PickersController < ApplicationController
    ALLOWED_INTENTS = %w[field collect].freeze

    before_action :validate_intent!
    before_action :assign_frame_context!

    def show
      if params[:closed].present?
        render :closed, layout: false
        return
      end

      load_buckets!

      if params[:list_only].present?
        @list_only = true
        render :list, layout: false
        return
      end

      render :show, layout: false
    end

    private

    def load_buckets!
      @q = params[:q].to_s.strip.downcase
      @intent = params[:intent]
      @target = params[:target].to_s.presence
      @field_name = params[:field_name].presence || "bullet[bucket_id]"
      @bullet_ids = params[:bullet_ids].to_s

      @buckets = Bucket.search_for(Current.user, query: @q, limit: nil).to_a
      @project_buckets = @buckets.select { |bucket| bucket.bucketable_type == "Project" }
      @collection_buckets = @buckets.select { |bucket| bucket.bucketable_type == "Collection" }
    end

    def assign_frame_context!
      @frame_id = params[:frame_id].presence || request.headers["Turbo-Frame"].presence || "modal"
      @panel_id = params[:panel_id].presence
      @inline = @frame_id != "modal"
    end

    def validate_intent!
      intent = params[:intent].to_s
      unless ALLOWED_INTENTS.include?(intent)
        head :bad_request
        return
      end

      if intent == "field" && params[:target].to_s.blank?
        head :bad_request
        return
      end

      return unless intent == "collect" && params[:bullet_ids].to_s.strip.blank?

      head :bad_request
    end
  end
end
