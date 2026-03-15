class CardsController < ApplicationController
  layout -> { 'mobile' if request.variant.mobile? }

  before_action :set_card, only: %i[show edit update destroy]

  def index
    @cards = set_page_and_extract_portion_from(
      Current.user.cards.includes(:tags).timeline_chronological,
      per_page: [5, 15, 30, 50]
    )
    @draft_count = Current.user.cards.drafts.where(pops_on: nil).count
  end

  def show
  end

  def new
    @card = Card.new
  end

  def create
    @card = Current.user.cards.new(card_params)
    @card.cardable = (cardable_type || Draft).new

    if @card.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @card }
      end
    else
      respond_to do |format|
        format.turbo_stream {
          render turbo_stream: turbo_stream.update("new_card", partial: "form", locals: { card: @card })
        }
        format.html { render :new, status: :unprocessable_entity }
      end
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
    params.expect(card: %i[content date ends_date pops_on tags_string])
  end

  def cardable_type
    params[:cardable_type].to_s.classify.safe_constantize.then do |klass|
      klass if klass && Card.cardable_types.include?(klass.name)
    end
  end
end
