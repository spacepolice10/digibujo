class HomeController < ApplicationController
  def index
    redirect_to cards_path
  end
end
