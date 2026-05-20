# frozen_string_literal: true

class CollectionsController < ApplicationController
  before_action :set_collection, only: %i[show destroy]

  def index
    @collections = Current.user.collections
  end

  def new
    @collection = Collection.new
  end

  def create
    @collection = Collection.new
    if save_collection_with_bucket(@collection)
      redirect_to collection_path(@collection)
    else
      @collection.name = collection_params[:name]
      render :new, status: :unprocessable_entity
    end
  end

  def show
    scope = Current.user.bullets.where(bucket_id: @collection.bucket.id)
                   .where(archived: false).distinct
    scope = scope.where(bulletable_type: selected_type) if selected_type.present?
    @bullets = set_page_and_extract_portion_from(scope, per_page: [5, 15, 30, 50])
  end

  def destroy
    dom = helpers.dom_id(@collection)
    @collection.bucket.destroy
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove(dom) }
      format.html { redirect_to buckets_path }
    end
  end

  private

  def set_collection
    @collection = Current.user.collections.find(params[:id])
  end

  def selected_type
    @selected_type ||= params[:type].to_s.classify.presence_in(Bullet.bulletable_types)
  end

  def collection_params
    params.require(:collection).permit(:name, :colour, :icon)
  end

  def save_collection_with_bucket(collection)
    ActiveRecord::Base.transaction do
      collection.save!
      Current.user.buckets.create!(
        bucketable: collection,
        name: collection_params[:name],
        colour: collection_params[:colour],
        icon: collection_params[:icon]
      )
    end
    true
  rescue ActiveRecord::RecordInvalid => e
    collection.errors.merge!(e.record.errors) if e.record.is_a?(Bucket)
    false
  end
end
