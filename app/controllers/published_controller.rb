class PublishedController < ApplicationController
  allow_unauthenticated_access only: ['show']

  def index
    @cards = Current.user.cards.published
  end

  def show
    @card = Card.find_by!(public_code: params[:code])
  end
end
