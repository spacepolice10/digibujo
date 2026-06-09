# frozen_string_literal: true

module ActiveStorage
  class InlineBlobsController < ApplicationController
    def show
      @blob = ActiveStorage::Blob.find_signed!(params[:signed_id])
      preview_src = blob_preview_src(@blob)

      render partial: "active_storage/blobs/blob", locals: { blob: @blob, preview_src: preview_src }
    end

    private

    def blob_preview_src(blob)
      return unless blob.representable?

      "/rails/active_storage/blobs/redirect/#{ERB::Util.url_encode(blob.signed_id)}/#{ERB::Util.url_encode(blob.filename.to_s)}"
    end
  end
end
