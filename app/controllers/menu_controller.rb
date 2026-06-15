# frozen_string_literal: true

class MenuController < ApplicationController
  def show
    @menu_q = params[:q].to_s.strip
  end
end
