# frozen_string_literal: true

class BucketsController < ApplicationController
  before_action :set_bucket

  def show
    redirect_to polymorphic_path(@bucket.bucketable)
  end

  private

  def set_bucket
    @bucket = Current.user.buckets.find(params[:id])
  end
end
