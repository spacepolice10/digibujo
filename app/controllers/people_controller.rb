# frozen_string_literal: true

class PeopleController < ApplicationController
  before_action :set_person, only: %i[show destroy]

  def index
    @people = Current.user.mentions.person.order(created_at: :desc)
  end

  def new
    @person = Current.user.mentions.person.build
  end

  def create
    @person = Current.user.mentions.person.build(person_params)
    if @person.save
      redirect_to home_path, notice: "Person created"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @bullets = set_page_and_extract_portion_from(
      @person.bullets.order(created_at: :desc),
      per_page: [ 5, 15, 30, 50 ]
    )
  end

  def destroy
    @person.destroy
    redirect_back fallback_location: people_path, notice: "Person deleted"
  end

  private

  def set_person
    @person = Current.user.mentions.person.find(params[:id])
  end

  def person_params
    params.require(:mention).permit(:name, :colour)
  end
end
