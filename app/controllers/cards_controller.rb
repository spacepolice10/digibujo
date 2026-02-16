class CardsController < ApplicationController
  before_action :set_card, only: %i[show edit update destroy]

  def index
    @cards = Current.user.cards.order(created_at: :desc)
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
      redirect_to @card
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @card.destroy
    redirect_to cards_path
  end

  private

  def set_card
    @card = Current.user.cards.find(params[:id])
  end

  def card_params
    params.expect(card: [:content])
  end

  def cardable_type
    params[:cardable_type].to_s.classify.safe_constantize.then do |klass|
      klass if klass && Card.cardable_types.include?(klass.name)
    end || Task
  end
end
