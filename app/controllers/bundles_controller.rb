class BundlesController < ApplicationController
  before_action :set_collection
  before_action :set_bundle, only: %i[show destroy]

  def show
    @bullets = Current.user.bullets
                      .where(bucket_id: @bundle.bucket.id)
                      .where(archived: false)
                      .distinct
                      .chronological
  end

  def new
    @bundle = @collection.bundles.new
  end

  def create
    @bundle = @collection.bundles.new
    if save_bundle_with_bucket(@bundle)
      redirect_back fallback_location: collection_path(@collection), notice: "Bundle created"
    else
      redirect_back fallback_location: collection_path(@collection), alert: "Could not create bundle"
    end
  end

  def destroy
    @bundle.bucket.destroy
    redirect_back fallback_location: collection_path(@collection), notice: "Bundle deleted"
  end

  private

  def set_collection
    @collection = Current.user.collections.find(params[:collection_id])
  end

  def set_bundle
    @bundle = @collection.bundles.find(params[:id])
  end

  def save_bundle_with_bucket(bundle)
    ActiveRecord::Base.transaction do
      bundle.save!
      Current.user.buckets.create!(
        bucketable: bundle,
        name: bundle_params[:name],
        colour: bundle_params[:colour],
        icon: bundle_params[:icon]
      )
    end
  end

  def bundle_params
    params.require(:bundle).permit(:name, :colour, :icon)
  end
end
