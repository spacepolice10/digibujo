# frozen_string_literal: true

class MentionsController < ApplicationController
  before_action :set_mention

  def show
    redirect_to public_send(:"#{@mention.kind}_path", @mention)
  end

  private

  def set_mention
    @mention = Current.user.mentions.find(params[:id])
  end
end
