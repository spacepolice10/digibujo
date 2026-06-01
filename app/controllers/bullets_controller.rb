class BulletsController < ApplicationController
  before_action :set_bullet, only: %i[show edit update destroy]

  def new
    @bullet = Current.user.bullets.build(pops_on: pops_on_param)
  end

  def create
    @bullet = create_bullet_from
    if @bullet.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to bullet_path(@bullet) }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.update(
              "new_bullet_form",
              partial: "editor",
              locals: {
                bullet: @bullet,
                bulletable_type: @bullet.bulletable_type,
                attributes: editor_attributes_for(@bullet)
              }
            ),
            turbo_stream.update(
              "toasts",
              partial: "shared/toasts",
              locals: { type: "errmsg", messages: @bullet.errors.full_messages }
            )
          ]
        end
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def edit; end

  def show; end

  def update
    if @bullet.update(bullet_params)
      BulletActivityRecorder.record_updated!(bullet: @bullet)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to bullet_path(@bullet) }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.update(
              dom_id(@bullet),
              partial: "editor",
              locals: {
                bullet: @bullet,
                bulletable_type: @bullet.bulletable_type,
                attributes: {}
              }
            ),
            turbo_stream.update(
              "toasts",
              partial: "shared/toasts",
              locals: { type: "errmsg", messages: @bullet.errors.full_messages }
            )
          ]
        end
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @bullet.destroy
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to daylog_path_to(@bullet.pops_on || Date.current) }
    end
  end

  private

  def set_bullet
    @bullet = Current.user.bullets.find(params[:id])
  end

  def bullet_params
    params.require(:bullet).permit(
      :content,
      :pops_on,
      :bulletable_type,
      :bucket_id,
      bulletable_attributes: {}
    )
  end

  def create_bullet_from
    permitted = bullet_params
    type_name = permitted[:bulletable_type].to_s
    attributes = permitted.except(:bulletable_type, "bulletable_type")
    Current.user.bullets.new(attributes.merge(bulletable: type_name.constantize.new))
  end

  def pops_on_param
    return if params[:pops_on].blank?

    Date.iso8601(params[:pops_on])
  rescue ArgumentError
    nil
  end

  def editor_attributes_for(bullet)
    {
      pops_on: bullet.pops_on,
      bucket_id: bullet.bucket_id
    }
  end
end
