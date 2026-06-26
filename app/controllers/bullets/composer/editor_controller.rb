# frozen_string_literal: true

module Bullets
  module Composer
    class EditorController < ApplicationController
      def create
        @type_name = Bullet::Params.resolve_type(params[:bulletable_type])
        return head :bad_request if @type_name.blank?

        @bullet = Current.user.bullets.new(bulletable_type: @type_name)
        @bullet.body = params[:body] if params[:body].present?
        @body_html = params[:body]
      end
    end
  end
end
