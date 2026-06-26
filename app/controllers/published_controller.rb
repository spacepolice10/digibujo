# frozen_string_literal: true

class PublishedController < ApplicationController
  layout 'public', only: :show

  allow_unauthenticated_access only: ['show']

  def index
    @bullets = Current.user.bullets.published
  end

  def show
    @bullet = Bullet.find_by!(public_code: params[:code])
  end
end
