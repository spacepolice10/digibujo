# frozen_string_literal: true

class BulletsController < ApplicationController
  class BulletTypeRequired < ArgumentError
    def initialize = super('Bullet type is required')
  end

  BULLET_PARAM_KEYS = %i[pops_on bulletable_type bucket_id].freeze

  rescue_from BulletTypeRequired, with: :bullet_type_required

  before_action :set_bullet, only: %i[show edit update destroy]

  def new
    type = resolve_bulletable_type(params[:bulletable_type])
    @bullet = Current.user.bullets.new(
      bulletable_type: type,
      pops_on: params[:pops_on],
      bucket_id: params[:bucket_id]
    )
    @bullet.bulletable = type.constantize.new if type
  end

  def create
    @bullet = Current.user.bullets.new(bullet_params)

    if @bullet.save
      redirect_to helpers.bullet_composer_return_path(@bullet), status: :see_other
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    return redirect_to bullet_path(@bullet) if @bullet.bulletable_type == 'Voice'
  end

  def show; end

  def update
    return redirect_to bullet_path(@bullet) if @bullet.bulletable_type == 'Voice'

    if @bullet.update(bullet_params)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to bullet_path(@bullet) }
      end
    else
      respond_to do |format|
        format.turbo_stream { notify_failure }
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

  def set_bullet
    @bullet = Current.user.bullets.find(params[:id])
  end

  def bullet_params
    type_class = bulletable_class_for_params

    params.require(:bullet).permit(
      *BULLET_PARAM_KEYS,
      bulletable_attributes: type_class.permitted_bullet_attributes
    ).then { |permitted| ensure_bulletable_defaults!(permitted, type_class) }
  end

  def resolve_bulletable_type(name)
    name.to_s.presence_in(Bullet.bulletable_types)
  end

  def bulletable_class_for_params
    type_name = resolve_bulletable_type(params.dig(:bullet, :bulletable_type))
    type_name ||= @bullet&.bulletable_type
    raise BulletTypeRequired if type_name.blank?

    type_name.constantize
  end

  # accepts_nested_attributes_for :bulletable needs both bulletable_type and
  # bulletable_attributes present, even when the form submits neither.
  def ensure_bulletable_defaults!(permitted, type_class)
    permitted[:bulletable_type] = type_class.name if permitted[:bulletable_type].blank?
    permitted[:bulletable_attributes] = {} if permitted[:bulletable_attributes].blank?
    permitted
  end

  def notify_failure
    render turbo_stream: turbo_stream.update(
      'toasts',
      partial: 'shared/toasts',
      locals: { type: 'errmsg', messages: @bullet.errors.full_messages }
    ), status: :unprocessable_entity
  end

  def bullet_type_required
    redirect_to new_bullet_path, alert: 'Pick a bullet type first'
  end
end
