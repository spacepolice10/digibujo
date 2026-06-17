# frozen_string_literal: true

class CollectionsController < ApplicationController
  include UserCollections
  before_action :set_collection, only: %i[show destroy]

  def index
    @collections = user_collections
  end

  def new
    @collection = Collection.new
  end

  def create
    @collection = Collection.new
    if save_collection_with_bucket(@collection)
      redirect_to collection_path(@collection), notice: 'Collection created'
    else
      @collection.name = collection_params[:name]
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @bundles = @collection.bundles.includes(bucket: :bullets)
    scoped_bullets = Current.user.bullets.where(bucket_id: @collection.bucket.id)
                            .where(archived: false).distinct
    scoped_bullets = scoped_bullets.where(bulletable_type: selected_type) if selected_type.present?
    @bullets = set_page_and_extract_portion_from(scoped_bullets, per_page: [5, 15, 30, 50])
  end

  def destroy
    @collection.bucket.destroy
    redirect_back fallback_location: home_path, notice: 'Collection deleted'
  end

  private

  def set_collection
    @collection = user_collections.find(params[:id])
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
  end
end
