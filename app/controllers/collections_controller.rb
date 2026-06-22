# frozen_string_literal: true

class CollectionsController < ApplicationController
  include UserCollections, PrepareBullets
  before_action :set_collection, only: %i[show destroy]
  before_action :prepare_collect_context, only: %i[new create]

  def index
    @collections = user_collections
  end

  def new
    @collection = Collection.new
  end

  def create
    @collection = Collection.new
    @collection.build_bucket(
      user: Current.user,
      name: collection_params[:name],
      colour: collection_params[:colour],
      icon: collection_params[:icon],
      description: collection_params[:description]
    )

    if @collection.save
      @collection.bucket.record_activity!(
        "created",
        metadata: { "bucketable_type" => @collection.bucket.bucketable_type }
      )

      if @bullet_ids.present?
        collect_bullets_into_collection!
        respond_to do |format|
          format.turbo_stream { render "bullets/collects/create" }
          format.html { redirect_to collect_return_path, notice: "Collection created" }
        end
      else
        redirect_to collection_path(@collection), notice: 'Collection created'
      end
    elsif @bullet_ids.present?
      render :new, status: :unprocessable_entity
    else
      render :new, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordInvalid => e
    @failed_bullet = e.record
    respond_to do |format|
      format.turbo_stream { render "bullets/collects/create", status: :unprocessable_entity }
      format.html do
        redirect_back fallback_location: home_path, alert: e.record.errors.full_messages.to_sentence
      end
    end
  end

  def show
    scoped_bullets = Current.user.bullets.where(bucket_id: @collection.bucket.id)
                            .where(archived: false).distinct
    scoped_bullets = scoped_bullets.where(bulletable_type: selected_type) if selected_type.present?
    @bullets = set_page_and_extract_portion_from(scoped_bullets, per_page: [5, 15, 30, 50])
  end

  def destroy
    @collection.bucket.archive!
    redirect_to home_path, notice: 'Collection archived'
  end

  private

  def set_collection
    @collection = user_collections.find(params[:id])
  end

  def selected_type
    @selected_type ||= params[:type].to_s.classify.presence_in(Bullet.bulletable_types)
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
      @bullets.lock.find_each { |bullet| bullet.collect!(bucket_id: @collection.bucket.id) }
    end
    @bullets.each(&:reload)
  end

  def collect_return_path
    @return_to.presence || collection_path(@collection)
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
