# frozen_string_literal: true

module Collections
  class BulletsController < ApplicationController
    include BulletCreation

    before_action :set_collection

    def new
      assign_composer_from_params(bucket_id: @collection.bucket.id)
      @form_url = collection_bullets_path(@collection)
    end

    def create
      create_bullet
    end

    private

    def set_collection
      @collection = Current.user.active_collections.find(params[:collection_id])
    end

    def build_bullet_for_create
      Current.user.bullets.new(bullet_params.merge(bucket_id: @collection.bucket.id))
    end

    def redirect_after_create
      redirect_to collection_path(@collection)
    end
  end
end
