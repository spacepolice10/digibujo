# frozen_string_literal: true

class Buckets::PinsController < ApplicationController
  before_action :set_buckets

  def create
    Bucket.transaction do
      @buckets.lock.find_each do |bucket|
        raise ActiveRecord::RecordInvalid.new(bucket) unless bucket.pin!
      end
    end
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back fallback_location: buckets_path }
    end
  rescue ActiveRecord::RecordInvalid => e
    @failed_bucket = e.record
    respond_to do |format|
      format.turbo_stream { render :create, status: :unprocessable_entity }
      format.html do
        redirect_back fallback_location: buckets_path,
                      alert: e.record.errors.full_messages.to_sentence
      end
    end
  end

  def destroy
    Bucket.transaction do
      @buckets.lock.find_each(&:unpin!)
    end
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back fallback_location: buckets_path }
    end
  rescue ActiveRecord::RecordInvalid => e
    @failed_bucket = e.record
    respond_to do |format|
      format.turbo_stream { render :destroy, status: :unprocessable_entity }
      format.html do
        redirect_back fallback_location: buckets_path,
                      alert: e.record.errors.full_messages.to_sentence
      end
    end
  end

  private

  def set_buckets
    ids = params.fetch(:bucket_ids, "").split(",").map(&:strip).grep(/\A\d+\z/).map(&:to_i).uniq
    raise ActiveRecord::RecordNotFound if ids.empty? || ids.size > 200

    @buckets = Current.user.buckets.where(id: ids).order(:id)
    raise ActiveRecord::RecordNotFound if @buckets.count != ids.size
  end
end
