class HomeController < ApplicationController
  def index
    redirect_to bullets_path
  end
end
