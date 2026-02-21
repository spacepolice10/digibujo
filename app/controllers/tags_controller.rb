class TagsController < ApplicationController
  def index
    @tags = if params[:q].present?
      Current.user.tags.where("name LIKE ?", "#{params[:q].strip.downcase}%").limit(10)
    else
      []
    end
  end
end
