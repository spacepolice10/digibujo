class BulletsController < ApplicationController
  before_action :set_bullet, only: %i[show edit update destroy]
  before_action :set_selected_date, only: %i[new create]

  def new
    @bullet = Bullet.new(pops_on: @selected_date)
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
          render turbo_stream: turbo_stream.update("new_bullet_form", partial: "form", locals: { bullet: @bullet })
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
          render turbo_stream: turbo_stream.update(
            dom_id(@bullet),
            partial: "form",
            locals: { bullet: @bullet }
          )
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

  def set_selected_date
    @selected_date = selected_date_param
  end

  def bullet_params
    params.require(:bullet).permit(
      :content,
      :pops_on,
      :context_bullet_id,
      :bulletable_type,
      :bucket_id,
      bulletable_attributes: {}
    )
  end

  def create_bullet_from
    permitted = bullet_params
    type_name = permitted[:bulletable_type].to_s
    attributes = permitted.except(:bulletable_type, 'bulletable_type')
    attributes[:pops_on] = resolve_pops_on(attributes[:pops_on])
    Current.user.bullets.new(attributes.merge(bulletable: type_name.constantize.new))
  end

  def resolve_pops_on(explicit)
    return parse_date_param(explicit) if explicit.present?
    return parse_date_param(params[:date]) if params[:date].present?

    @selected_date
  end

  def parse_date_param(value)
    return value if value.is_a?(Date)

    Date.iso8601(value.to_s)
  rescue ArgumentError
    @selected_date
  end

  def selected_date_param
    return Date.current if params[:date].blank?

    Date.iso8601(params[:date])
  rescue ArgumentError
    Date.current
  end
end
