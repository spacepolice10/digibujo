# frozen_string_literal: true

class SprintsController < ApplicationController
  include BulletListing, PrepareBullets, SprintAccessible
  before_action :set_sprint, only: %i[show destroy]
  before_action :prepare_collect_context, only: %i[new create]

  def index
    @sprints = Current.user.active_sprints
  end

  def new
    @sprint = Sprint.new(
      starts_on: Date.current,
      ends_on: Date.current + 13.days
    )
  end

  def create
    @sprint = Sprint.new(starts_on: sprint_params[:starts_on], ends_on: sprint_params[:ends_on])
    @sprint.build_bucket(
      user: Current.user,
      name: sprint_params[:name],
      colour: sprint_params[:colour],
      icon: sprint_params[:icon],
      description: sprint_params[:description]
    )

    if @sprint.save
      @sprint.bucket.record_activity!(
        "created",
        metadata: { "bucketable_type" => @sprint.bucket.bucketable_type }
      )

      if @bullet_ids.present?
        collect_bullets_into_sprint!
        respond_to do |format|
          format.turbo_stream { render "bullets/collects/create" }
          format.html { redirect_to collect_return_path, notice: "Sprint created" }
        end
      else
        redirect_to sprint_path(@sprint), notice: "Sprint created"
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
    set_bullet_listing(@sprint)
    @progress = @sprint.task_progress
  end

  def destroy
    @sprint.bucket.archive!
    redirect_to home_path, notice: "Sprint archived"
  end

  private

  def set_sprint
    @sprint = Current.user.active_sprints.find(params[:id])
  end

  def sprint_params
    params.require(:sprint).permit(:name, :colour, :icon, :description, :starts_on, :ends_on)
  end

  def prepare_collect_context
    @bullet_ids = params[:bullet_ids].to_s.presence
    @return_to = permitted_return_to(params[:return_to])
    return if @bullet_ids.blank?

    @bullets = bullets_from_param(@bullet_ids)
  end

  def collect_bullets_into_sprint!
    Bullet.transaction do
      @bullets.lock.find_each { |bullet| bullet.collect!(bucket_id: @sprint.bucket.id) }
    end
    @bullets.each(&:reload)
  end

  def collect_return_path
    @return_to.presence || sprint_path(@sprint)
  end

  def permitted_return_to(url)
    return if url.blank?

    uri = URI.parse(url.to_s)
    return if uri.host.present? && uri.host != request.host

    [ uri.path, uri.query ].compact.join("?").presence
  rescue URI::InvalidURIError
    nil
  end
end
