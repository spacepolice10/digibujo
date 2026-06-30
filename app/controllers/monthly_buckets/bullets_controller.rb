# frozen_string_literal: true

module MonthlyBuckets
  class BulletsController < ApplicationController
    include BulletCreation

    before_action :set_monthly_bucket

    def new
      prepare_bullet
    end

    def create
      create_bullet
    end

    private

    def redirect
      redirect_to monthly_bucket_path(@monthly_bucket)
    end

    def set_monthly_bucket
      @monthly_bucket = Current.user.monthly_buckets.find(params[:monthly_bucket_id])
    end
  end
end
