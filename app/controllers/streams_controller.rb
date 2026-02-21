class StreamsController < ApplicationController
  def index
    @streams = Current.user.streams.named
  end

  def show
    @stream = Current.user.streams.find(params[:id])
    @cards = @stream.cards
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
    Current.user.streams.find(params[:id]).destroy
    redirect_to root_path
  end

  private

  def stream_params
    params.require(:stream).permit(:name, :cardable_type, :sorted_by, :date_from, :date_to, :tag_names)
  end
end
