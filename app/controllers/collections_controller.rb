# frozen_string_literal: true

class CollectionsController < ApplicationController
  include PrepareBullets
  before_action :set_collection, only: %i[edit update destroy]
  before_action :prepare_collect_context, only: %i[new create]

  def new
    @collection = Current.user.collections.build
  end

  def create
    @collection = Current.user.collections.build(collection_params)

    if @collection.save
      @collection.record_activity!('created', metadata: { 'name' => @collection.name })

      if @bullet_ids.present?
        collect_bullets_into_collection!
        respond_to do |format|
          format.turbo_stream
          format.html { redirect_to collect_return_path, notice: 'Collection created' }
        end
      else
        redirect_to bullets_path(collection: @collection.name), notice: 'Collection created'
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

  def edit; end

  def update
    if @collection.update(collection_params)
      redirect_to bullets_path(collection: @collection.name), notice: 'Collection updated'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @collection.archive!
    redirect_to search_path, notice: 'Collection archived'
  end

  private

  def set_collection
    @collection = Current.user.collections.active.find(params[:id])
  end

  def collection_params
    params.require(:collection).permit(:name, :colour, :icon, :description)
  end

  def prepare_collect_context
    @bullet_ids = params[:bullet_ids].to_s.presence
    @return_to = permitted_return_to(params[:return_to])
    return if @bullet_ids.blank?

    @bullets = bullets_from_param(@bullet_ids)
  end

  def collect_bullets_into_collection!
    Bullet.transaction do
      @bullets.lock.find_each { |bullet| bullet.collect!(collection_id: @collection.id) }
    end
    @bullets.each(&:reload)
  end

  def collect_return_path
    @return_to.presence || bullets_path(collection: @collection.name)
  end

  def permitted_return_to(url)
    return if url.blank?

    uri = URI.parse(url.to_s)
    return if uri.host.present? && uri.host != request.host

    [uri.path, uri.query].compact.join('?').presence
  rescue URI::InvalidURIError
    nil
  end
end
