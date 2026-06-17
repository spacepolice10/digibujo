# frozen_string_literal: true

class BundlesController < ApplicationController
  include UserCollections

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
    @bundle = @collection.bundles.build(user: Current.user)
    @bundle.build_bucket
  end

  def create
    @bundle = @collection.bundles.build(user: Current.user)
    @bundle.build_bucket(
      user: Current.user,
      name: bundle_params[:name],
      colour: bundle_params[:colour],
      icon: bundle_params[:icon]
    )

    if @bundle.save
      redirect_to collection_path(@collection), notice: 'Bundle created'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    @bundle.bucket.destroy
    redirect_to collection_path(@collection), notice: 'Bundle deleted'
  end

  private

  def set_collection
    @collection = user_collections.find(params[:collection_id])
  end

  def set_bundle
    @bundle = @collection.bundles.find(params[:id])
  end

  def bundle_params
    params.require(:bundle).permit(:name, :colour, :icon)
  end
end
