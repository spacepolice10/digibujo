# frozen_string_literal: true

class CollectionsController < ApplicationController
  include PrepareBullets, ReturnToPath

  before_action :set_collection, only: %i[show edit update destroy]
  before_action :prepare_collect_context, only: %i[new create]
  return_to_from :param, only: %i[new create]

  def index
    @collections = Current.user.collections.order(:name)
  end

  def new
    @collection = Current.user.collections.build
  end

  def create
    @collection = Current.user.collections.build(collection_params)

    if @collection.save
      if @bullet_ids.present?
        collect_bullets_into_collection!
        respond_to do |format|
          format.html { redirect_to collect_return_path, notice: 'Collection created' }
        end
      else
        redirect_to collections_path, notice: 'Collection created'
      end
    else
      render :new, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordInvalid => e
    @failed_bullet = e.record
    respond_to do |format|
      format.turbo_stream { render 'bullets/collects/create', status: :unprocessable_entity }
      format.html do
        redirect_back fallback_location: search_path, alert: e.record.errors.full_messages.to_sentence
      end
    end
  end

  def show; end

  def edit; end

  def update
    if @collection.update(collection_params)
      redirect_to collection_path(@collection), notice: 'Collection updated'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @collection.destroy
    redirect_to search_path, notice: 'Collection deleted'
  end

  private

  def set_collection
    @collection = Current.user.collections.find(params[:id])
  end

  def collection_params
    params.require(:collection).permit(:name, :colour, :icon, :description)
  end

  def prepare_collect_context
    @bullet_ids = params[:bullet_ids].to_s.presence
    return if @bullet_ids.blank?

    @bullets = prepare_bullets_from(@bullet_ids)
  end

  def collect_bullets_into_collection!
    Bullet.transaction do
      @bullets.lock.find_each { |bullet| bullet.collect!(collection_id: @collection.id) }
    end
    @bullets.each(&:reload)
  end

  def collect_return_path
    @return_to.presence || collection_path(@collection)
  end
end
