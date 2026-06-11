# frozen_string_literal: true

class MenuController < ApplicationController
  def show
    @q = params[:q].to_s.strip
  end
end
