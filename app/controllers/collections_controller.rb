class CollectionsController < ApplicationController
  before_action :set_collection, only: %i[show destroy]

  def index
    @query = params[:q].to_s.strip.downcase
    @collections = if @query.present?
                     Current.user.collections.where("name LIKE ?", "#{@query}%").limit(10)
                   else
                     Current.user.collections
                   end
    @exact_match = @collections.any? { |collection| collection.name == @query }
    render json: { collections: @collections.map { |collection| { id: collection.id, name: collection.name, colour: collection.colour } } }
  end

  def show
    scope = Current.user.cards.includes(:collection).where(collection: @collection)
    scope = scope.where(cardable_type: selected_type) if selected_type.present?
    @cards = set_page_and_extract_portion_from(scope.order(created_at: :desc), per_page: [5, 15, 30, 50])
  end

  def destroy
    @collection.destroy
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove(@collection) }
      format.html { redirect_to indexing_path }
    end
  end

  private

  def set_collection
    @collection = Current.user.collections.find(params[:id])
  end

  def selected_type
    @selected_type ||= params[:type].to_s.classify.presence_in(Card.cardable_types)
  end
end
