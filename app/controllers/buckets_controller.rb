# frozen_string_literal: true

class BucketsController < ApplicationController
  def show
    @bucket = Current.user.buckets.find(params[:id])
    @bullets = @bucket.bullets.includes(bulletable: :rich_text_body).order(:created_at)
  end
end
