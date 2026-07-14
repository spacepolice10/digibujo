# frozen_string_literal: true

module People
  class PinsController < ApplicationController
    before_action :set_person

    def create
      @person.pin!
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_back fallback_location: people_path }
      end
    end

    def destroy
      @person.unpin!
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_back fallback_location: people_path }
      end
    end

    private

    def set_person
      @person = Current.user.mentions.person.find(params.require(:person_id))
    end
  end
end
