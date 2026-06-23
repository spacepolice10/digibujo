# frozen_string_literal: true

module MonthlyBuckets
  class BulletsController < ApplicationController
    before_action :set_monthly_bucket

    def new
      @bullet = Current.user.bullets.build(
        pops_on: params[:pops_on],
        bucket_id: @monthly_bucket.bucket.id
      )
      @bullet.bulletable_type = params[:bulletable_type].presence || Bullet::DEFAULT_COMPOSER_TYPE
      @bullet.bulletable = @bullet.bulletable_type.constantize.new
    end

    def create
      result = BulletCreator.new(Current.user, bullet_params.merge(
        bucket_id: @monthly_bucket.bucket.id
      )).call
      @bullet = result.bullet
      @monthly_bucket
      if result.success?
        respond_to do |format|
          format.turbo_stream
          format.html { redirect_to monthly_bucket_path(@monthly_bucket) }
        end
      else
        respond_to do |format|
          format.turbo_stream { render_invalid_create }
          format.html { render :new, status: :unprocessable_entity }
        end
      end
    end

    private

    def set_monthly_bucket
      @monthly_bucket = Current.user.monthly_buckets.find(params[:monthly_bucket_id])
    end

    def bullet_params
      params.require(:bullet).permit(
        :body, :rich_body, :pops_on, :bulletable_type, :bucket_id,
        attachments: [],
        bulletable_attributes: %i[mood]
      )
    end

    def render_invalid_create
      render turbo_stream: turbo_stream.update(
        'toasts',
        partial: 'shared/toasts',
        locals: { type: 'errmsg', messages: @bullet.errors.full_messages }
      )
    end
  end
end
