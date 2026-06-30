# frozen_string_literal: true

module Collections
  class ExportsController < ApplicationController
    include ExportDownload

    before_action :set_collection
    before_action :prepare_export_bullets

    def show
      download_export_html(
        template: 'collections/exports/show',
        filename: export_filename
      )
    end

    private

    def set_collection
      @collection = Current.user.active_collections.find(params[:collection_id])
    end

    def prepare_export_bullets
      listing = Bullet::Listing.for(user: Current.user, context: @collection, params: {})
      @bullets = listing.relation
                        .includes(:bulletable, bucket: :bucketable)
                        .with_rich_text_body
                        .reorder(created_at: :asc)
    end

    def export_filename
      slug = @collection.bucket.name.parameterize
      "digibujo-#{slug}-export-#{Date.current.iso8601}.html"
    end
  end
end
