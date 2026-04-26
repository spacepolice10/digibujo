class HomeController < ApplicationController
  def index
    redirect_to todays_path
  end
end
