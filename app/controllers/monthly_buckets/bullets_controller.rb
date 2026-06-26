# frozen_string_literal: true

module MonthlyBuckets
  class BulletsController < ApplicationController
    before_action :set_monthly_bucket

    def new
      assign_composer_state
    end

    def create
      @bullet = Current.user.bullets.new(
        bullet_params.merge(bucket_id: @monthly_bucket.bucket.id)
      )

      if @bullet.save
        respond_to do |format|
          format.turbo_stream
          format.html { redirect_to monthly_bucket_path(@monthly_bucket) }
        end
      else
        respond_to do |format|
          format.turbo_stream { notify }
          format.html { render_composer_form(status: :unprocessable_entity) }
        end
      end
    rescue Bullet::Params::TypeRequired
      respond_to do |format|
        format.turbo_stream { notify_type_required }
        format.html do
          redirect_to monthly_bucket_path(@monthly_bucket), alert: 'Bullet type is required'
        end
      end
    end

    private

    def set_monthly_bucket
      @monthly_bucket = Current.user.monthly_buckets.find(params[:monthly_bucket_id])
    end

    def bullet_params
      Bullet::Params.permit(params)
    end

    def assign_composer_state
      preview = Bullet::Params.preview(params, bucket_id: @monthly_bucket.bucket.id)
      @bullet = Current.user.bullets.build(preview.except(:bulletable_attributes))
      @composer_attributes = {
        pops_on: preview[:pops_on],
        bucket_id: preview[:bucket_id]
      }.compact
      @composer_id = params[:composer_id].presence || composer_frame_id(preview[:pops_on])
    end

    def composer_frame_id(pops_on = nil)
      pops_on.present? ? "composer_#{pops_on.to_date.iso8601}" : "composer_unplanned"
    end

    def render_composer_form(status: :ok)
      @composer_id = params.dig(:bullet, :composer_id).presence || composer_frame_id(@bullet.pops_on)
      @composer_attributes = {
        pops_on: @bullet.pops_on,
        bucket_id: @monthly_bucket.bucket.id
      }.compact
      render_composer_content(status: status)
    end

    def render_composer_content(status: :ok)
      render partial: "monthly_buckets/bullets/composer_content",
             locals: {
               bullet: @bullet,
               monthly_bucket: @monthly_bucket,
               composer_id: @composer_id,
               composer_attributes: @composer_attributes
             },
             layout: false,
             status: status
    end

    def notify_type_required
      render turbo_stream: turbo_stream.update(
        'toasts',
        partial: 'shared/toasts',
        locals: { type: 'errmsg', messages: ['Bullet type is required'] }
      ), status: :unprocessable_entity
    end

    def notify
      render turbo_stream: turbo_stream.update(
        'toasts',
        partial: 'shared/toasts',
        locals: { type: 'errmsg', messages: @bullet.errors.full_messages }
      ), status: :unprocessable_entity
    end
  end
end
