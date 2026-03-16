class StreamsController < ApplicationController
  layout -> { "mobile" if request.variant.mobile? }

  def index
    @streams = Current.user.streams.ordered
  end

  def show
    @stream = Current.user.streams.find(params[:id])
    @cards = set_page_and_extract_portion_from(@stream.cards, per_page: [ 5, 15, 30, 50 ])
  end

  def new
    @stream = Current.user.streams.new
  end

  def create
    @stream = Current.user.streams.new(stream_params)
    if @stream.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to stream_path(@stream) }
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    stream = Current.user.streams.find(params[:id])
    if stream.default?
      head :forbidden
    else
      stream.destroy
      redirect_to root_path
    end
  end

  private

  def stream_params
    params.require(:stream).permit(:name, :cardable_type, :sorted_by, :date_from, :date_to, :tags)
  end
end
