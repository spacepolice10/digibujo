class CardsController < ApplicationController
  before_action :set_card, only: %i[show edit update destroy]

  def index
    @selected_date = Date.current
    @on_todays_route = todays_route?(request.path)
    @cards = set_page_and_extract_portion_from(
      Current.user.cards.includes(:collection).timeline.for_day(@selected_date),
      per_page: [5, 15, 30, 50]
    )
  end

  def new
    @card = Card.new
  end

  def create
    @card = Current.user.cards.new(base_card_params)
    @card.cardable = cardable_type.new(cardable_attribute_params)
    @on_todays_route = todays_route?(referer_path || request.path)

    if @card.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to card_path(@card) }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.update('card_form', partial: 'form', locals: { card: @card })
        end
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def edit
  end

  def show
  end

  def update
    if @card.update(base_card_params)
      @card.cardable.update(cardable_attribute_params) unless cardable_attribute_params.empty?
      redirect_to card_path(@card)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @card.destroy
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to cards_path }
    end
  end

  private

  def set_card
    @card = Current.user.cards.find(params[:id])
  end

  def card_params
    params.expect(card: %i[content date ends_date pops_on collection_id collection_name context_card_id])
  end

  def cardable_type
    params.dig(:card, :cardable_type).to_s.classify.safe_constantize.then do |klass|
      klass if klass && Card.cardable_types.include?(klass.name)
    end
  end

  def cardable_attribute_params
    params.dig(:card, :cardable_attributes)&.permit(:mood)&.to_h || {}
  end

  def base_card_params
    card_params
  end

  def todays_route?(path)
    path == todays_path
  end

  def referer_path
    return if request.referer.blank?

    URI.parse(request.referer).path
  rescue URI::InvalidURIError
    nil
  end

end
