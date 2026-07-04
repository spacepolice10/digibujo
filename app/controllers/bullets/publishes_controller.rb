# frozen_string_literal: true

module Bullets
  class PublishesController < ApplicationController
    include PrepareBullets

    before_action :prepare_bullets

    def create
      Bullet.transaction do
        @bullets.lock.find_each(&:publish!)
      end

      redirect_to @bullets.first
    end

    def destroy
      Bullet.transaction do
        @bullets.lock.find_each(&:unpublish!)
      end

      redirect_to @bullets.first
    end
  end
end
