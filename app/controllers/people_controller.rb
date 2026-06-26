# frozen_string_literal: true

class PeopleController < ApplicationController
  include BulletListing

  before_action :set_person, only: %i[show edit update destroy]

  def index
    @people = Current.user.people.order(created_at: :desc)
    @people = @people.where('name LIKE ?', "%#{sanitized_string}%") if sanitized_string.present?
  end

  def new
    @person = Person.new
    @person.handles.build(kind: :email)
  end

  def create
    @person = Current.user.people.build(person_params)
    if @person.save
      redirect_to home_path, notice: 'Person created'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @person.handles.build(kind: :email) if @person.handles.empty?
  end

  def update
    if @person.update(person_params)
      redirect_to person_path(@person), notice: 'Person updated'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def show
    set_bullet_listing(@person)
  end

  def destroy
    @person.destroy
    redirect_back fallback_location: people_path, notice: 'Person deleted'
  end

  private

  def set_person
    @person = Current.user.people.includes(:handles).find(params[:id])
  end

  def sanitized_string
    @sanitized_string ||= ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.strip.downcase)
  end

  def person_params
    params.require(:person).permit(
      :name, :colour, :icon, :avatar,
      handles_attributes: [ :id, :kind, :platform, :data, :position, :_destroy ]
    )
  end
end
