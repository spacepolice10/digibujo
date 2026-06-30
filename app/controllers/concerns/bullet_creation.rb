# frozen_string_literal: true

module BulletCreation
  extend ActiveSupport::Concern

  private

  def prepare_bullet
    @bullet = Current.user.bullets.new(
      bulletable_type: Bullet::Params.resolve_type(params[:bulletable_type]),
      pops_on: params[:pops_on],
      bucket_id: params[:bucket_id]
    )
  end

  def assign_composer_from_params(bucket_id: params[:bucket_id], pops_on: params[:pops_on])
    @bullet = Current.user.bullets.new(
      bulletable_type: Bullet::Params.resolve_type(params[:bulletable_type]),
      pops_on: pops_on,
      bucket_id: bucket_id
    )
  end

  def create_bullet
    @bullet = Current.user.bullets.new(bullet_params)
    if @bullet.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect }
      end
    else
      respond_to do |format|
        format.turbo_stream { notify(@bullet) }
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def bullet_params
    Bullet::Params.permit(params, bullet: @bullet)
  end

  def redirect
    redirect_back(fallback_location: root_path)
  end

  def notify(record)
    render turbo_stream: turbo_stream.update(
      'toasts',
      partial: 'shared/toasts',
      locals: { type: 'errmsg', messages: record.errors.full_messages }
    ), status: :unprocessable_entity
  end
end
