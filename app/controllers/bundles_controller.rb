# frozen_string_literal: true

class BundlesController < ApplicationController
  include UserCollections

  before_action :set_collection, if: -> { params[:collection_id].present? }
  before_action :set_bundle, only: %i[show destroy]

  def show
    @bullets = Current.user.bullets
                      .where(bucket_id: @bundle.bucket.id)
                      .where(archived: false)
                      .distinct
                      .chronological
  end

  def new
    @bundle = Bundle.new(user: Current.user)
    @bundle.build_bucket
    @bundle.collection = @collection if @collection
  end

  def create
    @bundle = Bundle.new(user: Current.user)
    @bundle.build_bucket(
      user: Current.user,
      name: bundle_params[:name],
      colour: bundle_params[:colour],
      icon: bundle_params[:icon]
    )

    if @collection
      @bundle.collection = @collection
    elsif bundle_params[:collection_id].present?
      @bundle.collection = user_collections.find_by(id: bundle_params[:collection_id])
    end

    if @bundle.save
      redirect_to @bundle.collection ? collection_path(@bundle.collection) : bundle_path(@bundle), notice: 'Bundle created'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    @bundle.bucket.destroy
    redirect_back fallback_location: (@bundle.collection ? collection_path(@bundle.collection) : home_path), notice: 'Bundle deleted'
  end

  private

  def set_collection
    @collection = user_collections.find(params[:collection_id])
  end

  def set_bundle
    @bundle = if @collection
                @collection.bundles.find(params[:id])
              else
                Bundle.where(user: Current.user).find(params[:id])
              end
  end

  def bundle_params
    params.require(:bundle).permit(:name, :colour, :icon, :collection_id)
  end
end
