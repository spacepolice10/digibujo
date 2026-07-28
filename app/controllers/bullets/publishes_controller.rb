# frozen_string_literal: true

module Bullets
  class PublishesController < ApplicationController
    include PrepareBullets

    before_action :prepare_bullets

    def create
      Bullet.transaction do
        @bullets.lock.find_each(&:publish!)
      end
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to published_path(@bullets.first.reload.public_code) }
      end
    end

    def destroy
      Bullet.transaction do
        @bullets.lock.find_each(&:unpublish!)
      end
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @bullets.first }
      end
    end
  end
end
