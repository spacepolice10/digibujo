class CardsController < ApplicationController
  before_action :set_card, only: %i[show edit update destroy]

  def index
    @popped_cards = Current.user.cards.includes(:tags).popped.order(pops_on: :asc)
    @cards = Current.user.cards.includes(:tags).timeline_order
  end

  def show
  end

  def new
    @card = Card.new
  end

  def create
    @card = Current.user.cards.new(card_params)
    @card.cardable = cardable_type.new

    if @card.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @card }
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @card.update(card_params)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @card }
      end
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
    params.expect(card: [ :content, :date, :pops_on, :tag_names ])
  end

  def cardable_type
    params[:cardable_type].to_s.classify.safe_constantize.then do |klass|
      klass if klass && Card.cardable_types.include?(klass.name)
    end || Task
  end
end
