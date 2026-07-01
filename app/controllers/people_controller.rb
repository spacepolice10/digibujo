# frozen_string_literal: true

class PeopleController < ApplicationController
  include BulletListing

  before_action :set_person, only: %i[show edit update destroy]
  before_action :prepare_contact_fields, only: %i[edit]

  def index
    @people = Current.user.people.order(created_at: :desc)
    @people = @people.where('name LIKE ?', "%#{sanitized_string}%") if sanitized_string.present?
  end

  def new
    @person = Person.new
    prepare_contact_fields
  end

  def create
    @person = Current.user.people.build(person_params)
    if @person.save
      redirect_to home_path, notice: 'Person created'
    else
      prepare_contact_fields
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @person.update(person_params)
      redirect_to person_path(@person), notice: 'Person updated'
    else
      prepare_contact_fields
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

  def prepare_contact_fields
    return unless @person

    @email_handle = @person.handles.email.first || @person.handles.build(kind: :email)
    @phone_handle = @person.handles.phone.first || @person.handles.build(kind: :phone)
    @email_handle_index = @email_handle.persisted? ? @email_handle.id : 0
    @phone_handle_index = if @phone_handle.persisted?
      @phone_handle.id
    elsif @email_handle.persisted?
      @email_handle.id + 1
    else
      1
    end
  end

  def sanitized_string
    @sanitized_string ||= ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.strip.downcase)
  end

  def person_params
    params.require(:person).permit(
      :name, :colour, :icon, :avatar,
      handles_attributes: [ :id, :kind, :platform, :data, :position, :_destroy ]
    ).tap do |permitted|
      permitted[:handles_attributes]&.each do |_key, attrs|
        attrs[:_destroy] = "1" if attrs[:id].present? && attrs[:data].blank?
      end
    end
  end
end
