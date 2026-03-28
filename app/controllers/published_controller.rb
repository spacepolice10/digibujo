class PublishedController < ApplicationController
  allow_unauthenticated_access
  layout "public"

  def show
    @card = Card.find_by!(public_code: params[:code])
  end
end
