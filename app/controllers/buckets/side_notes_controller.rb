# frozen_string_literal: true

module Buckets
  class SideNotesController < ApplicationController
    before_action :set_bucket

    def update
      @bucket.update!(side_note_params)
      head :no_content
    end

    private

    def set_bucket
      @bucket = Current.user.buckets.find(params[:bucket_id])
    end

    def side_note_params
      params.require(:bucket).permit(:side_note)
    end
  end
end
