# frozen_string_literal: true

class MenuController < ApplicationController
  def show
    redirect_to home_path if request.variant.include?(:mobile)
  end
end
