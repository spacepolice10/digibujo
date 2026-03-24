class TagsController < ApplicationController
  layout -> { request.headers["Turbo-Frame"].blank? ? "main-layout" : nil }

  before_action :set_tag, only: :destroy

  def index
    @query = params[:q].to_s.strip.downcase
    @tags = if @query.present?
              Current.user.tags.where('name LIKE ?', "#{@query}%").limit(10)
            else
              Current.user.tags
            end
    @exact_match = @tags.any? { |t| t.name == @query }
  end

  def destroy
    @tag.destroy
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove(@tag) }
      format.html { redirect_to tags_path }
    end
  end

  private

  def set_tag
    @tag = Current.user.tags.find(params[:id])
  end
end
