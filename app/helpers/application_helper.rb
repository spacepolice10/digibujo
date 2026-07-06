# frozen_string_literal: true

module ApplicationHelper
  def bulk_menu_review_period
    return unless controller_name == "reviews" && action_name == "show"
    return unless @review_from && @review_to

    { from: @review_from, to: @review_to }
  end
end
