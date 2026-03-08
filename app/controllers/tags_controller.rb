class TagsController < ApplicationController
  def index
    @query = params[:q].to_s.strip.downcase
    @tags = if @query.present?
      Current.user.tags.where("name LIKE ?", "#{@query}%").limit(10)
    else
      []
    end
    @exact_match = @tags.any? { |t| t.name == @query }
  end
end
