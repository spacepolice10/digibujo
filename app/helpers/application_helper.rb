# frozen_string_literal: true

module ApplicationHelper
  def current_user
    Current.user
  end
end
