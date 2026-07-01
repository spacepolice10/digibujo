# frozen_string_literal: true

class BulletsController < ApplicationController
  include BulletCreation

  before_action :set_bullet, only: %i[show edit update destroy]
  before_action :redirect_voice_edit, only: %i[edit update]

  # Full-page bullet composer (not the inline/turbo-frame composer used by daylog
  # and monthly bucket). Renders a real page and redirects on success instead of
  # responding with a turbo stream.
  def new
    @return_to = permitted_return_to(params[:return_to]) || permitted_return_to(request.referer)
    @bullet = Current.user.bullets.new(
      bulletable_type: Bullet::Params.resolve_type(params[:bulletable_type]),
      pops_on: params[:pops_on],
      bucket_id: params[:bucket_id]
    )
  end

  def create
    @return_to = permitted_return_to(params[:return_to])
    @bullet = Current.user.bullets.new(bullet_params)

    if @bullet.save
      redirect_to after_create_path
    else
      render :new, status: :unprocessable_entity
    end
  rescue Bullet::Params::TypeRequired
    redirect_to new_bullet_path(return_to: @return_to), alert: 'Pick a bullet type first'
  end

  def edit; end

  def show; end

  def update
    if @bullet.update(bullet_params)
      @bullet.record_activity!('updated')
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to bullet_path(@bullet) }
      end
    else
      respond_to do |format|
        format.turbo_stream { notify(@bullet) }
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @bullet.destroy
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to daylog_path(date: (@bullet.pops_on || Date.current).iso8601) }
    end
  end

  private

  def after_create_path
    if params[:another].present?
      new_bullet_path(
        bulletable_type: @bullet.bulletable_type,
        pops_on: @bullet.pops_on,
        bucket_id: @bullet.bucket_id,
        return_to: @return_to
      )
    else
      @return_to.presence || bullet_path(@bullet)
    end
  end

  def set_bullet
    @bullet = Current.user.bullets.find(params[:id])
  end

  def redirect_voice_edit
    return unless @bullet.bulletable_type == "Voice"

    redirect_to bullet_path(@bullet)
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
