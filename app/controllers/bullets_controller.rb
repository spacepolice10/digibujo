# frozen_string_literal: true

class BulletsController < ApplicationController
  before_action :set_bullet, only: %i[show edit update destroy]

  def index
    bullets = Current.user.bullets
                     .active
                     .includes(:bulletable, :rich_text_body, bucket: :bucketable)
                     .order(created_at: :desc, id: :desc)
    @bullets = set_page_and_extract_portion_from(bullets, per_page: [30, 50, 100])
  end

  def create
    @bullet = Current.user.bullets.new(bullet_params)

    if @bullet.save
      created_response
    else
      failed_create_response
    end
  end

  def edit; end

  def show; end

  def update
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

  def created_response
    respond_to do |format|
      format.json do
        response.set_header('Location', bullet_url(@bullet))
        render :create, status: :created
      end
      format.turbo_stream { render :create }
      format.html { redirect_to bullet_path(@bullet), status: :see_other }
    end
  end

  def failed_create_response
    respond_to do |format|
      format.json { render json: bullet_errors_by_attribute, status: :unprocessable_entity }
      format.turbo_stream { notify_failure }
      format.html do
        redirect_to daylog_path, alert: bullet_errors.to_sentence, status: :see_other
      end
    end
  end

  def set_bullet
    @bullet = Current.user.bullets.find(params[:id])
  end

  def bullet_params
    attributes = allowed_bulletable_entity.permitted_bullet_attributes

    if @bullet&.persisted?
      params.require(:bullet).permit(:body, bulletable_attributes: attributes)
    else
      params.require(:bullet).permit(%i[pops_on bulletable_type bucket_id body], bulletable_attributes: attributes)
    end
  end

  # Unknown / missing type is a bad request, not a soft redirect.
  def allowed_bulletable_entity
    name = (@bullet&.bulletable_type || params.dig(:bullet, :bulletable_type)).to_s
    allowed = name.presence_in(Bullet.bulletable_types)
    raise ActionController::ParameterMissing, 'bulletable_type' unless allowed

    allowed.constantize
  end

  def notify_failure(messages = bullet_errors)
    render turbo_stream: turbo_stream.update(
      'toasts',
      partial: 'shared/toasts',
      locals: { type: 'errmsg', messages: Array(messages) }
    ), status: :unprocessable_entity
  end

  def bullet_errors
    own = @bullet.errors.reject { |error| error.attribute == :bulletable }.map(&:full_message)
    nested = Array(@bullet.bulletable&.errors&.full_messages)
    (own + nested).uniq.presence || ['Bullet could not be saved']
  end

  def bullet_errors_by_attribute
    errors = {}
    @bullet.errors.each do |error|
      next if error.attribute == :bulletable

      (errors[error.attribute] ||= []) << error.message
    end
    @bullet.bulletable&.errors&.each do |error|
      (errors[error.attribute] ||= []) << error.message
    end
    errors.presence || { base: ['Bullet could not be saved'] }
  end
end
