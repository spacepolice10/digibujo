class BulletsController < ApplicationController
  before_action :set_bullet, only: %i[show edit update destroy]

  def index
    @selected_date = selected_date_param
    timeline = Current.user.bullets.includes(:project).timeline
                      .scheduled_on_date(@selected_date)
                      .where(archived: false)

    @bullets = set_page_and_extract_portion_from(
      timeline,
      per_page: [15, 30, 50]
    )
  end

  def new
    @bullet = Bullet.new
  end

  def create
    @bullet = create_bullet_from_form
    if @bullet.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to bullet_path(@bullet) }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.update('bullet_form', partial: 'form', locals: { bullet: @bullet })
        end
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def edit; end

  def show; end

  def update
    if @bullet.update(bullet_params)
      redirect_to bullet_path(@bullet)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @bullet.destroy
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to bullets_path }
    end
  end

  private

  def set_bullet
    @bullet = Current.user.bullets.find(params[:id])
  end

  def bullet_params
    params.require(:bullet).permit(
      :content,
      :scheduled_on,
      :project_id,
      :project_name,
      :context_bullet_id,
      :bulletable_type,
      bulletable_attributes: {}
    )
  end

  def create_bullet_from_form
    permitted = bullet_params
    type_name = permitted[:bulletable_type].to_s
    attributes = permitted.except(:bulletable_type, "bulletable_type")
    Current.user.bullets.new(attributes.merge(bulletable: type_name.constantize.new))
  end

  def selected_date_param
    return Date.current if params[:date].blank?

    Date.iso8601(params[:date])
  rescue ArgumentError
    Date.current
  end
end
