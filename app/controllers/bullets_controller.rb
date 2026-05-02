class BulletsController < ApplicationController
  before_action :set_bullet, only: %i[show edit update destroy]

  def index
    @selected_date = selected_date_param
    timeline = Current.user.bullets.includes(:project).timeline
                      .scheduled_on_date(@selected_date)
                      .where(archived: false)

    @bullets = set_page_and_extract_portion_from(
      timeline,
      per_page: [5, 15, 30, 50]
    )
  end

  def new
    @bullet = Bullet.new
  end

  def create
    attrs = normalized_bullet_params
    bulletable_attrs = attrs.delete(:bulletable_attributes) || {}
    klass = resolved_bulletable_class(attrs.delete(:bulletable_type))

    @bullet = Current.user.bullets.new(attrs)
    @bullet.bulletable = klass.new(bulletable_attrs)

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
    attrs = normalized_bullet_params
    bulletable_attrs = attrs.delete(:bulletable_attributes) || {}
    new_type = attrs.delete(:bulletable_type)

    @bullet.assign_attributes(attrs)
    if new_type.present? && new_type != @bullet.bulletable_type
      @bullet.bulletable = resolved_bulletable_class(new_type).new(bulletable_attrs)
    elsif bulletable_attrs.present?
      @bullet.bulletable.assign_attributes(bulletable_attrs)
    end

    if @bullet.save
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
    params.expect(
      bullet: [
        :content,
        :scheduled_on,
        :project_id,
        :project_name,
        :context_bullet_id,
        :bulletable_type,
        { bulletable_attributes: {} }
      ]
    )
  end

  def normalized_bullet_params
    attrs = bullet_params.to_h.deep_symbolize_keys
    if attrs[:bulletable_type].present?
      attrs[:bulletable_type] = attrs[:bulletable_type].to_s.classify
    end
    attrs
  end

  def resolved_bulletable_class(type_name)
    type_name.to_s.classify.safe_constantize.then do |klass|
      return klass if klass && Bullet.bulletable_types.include?(klass.name)

      raise NameError, "Invalid bulletable type: #{type_name.inspect}"
    end
  end



  def selected_date_param
    return Date.current if params[:date].blank?

    Date.iso8601(params[:date])
  rescue ArgumentError
    Date.current
  end
end
