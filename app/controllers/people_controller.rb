# frozen_string_literal: true

class PeopleController < ApplicationController
  before_action :set_person, only: %i[show destroy]

  def index
    @people = Current.user.people.order(created_at: :desc)
    @people = @people.where('name LIKE ?', "%#{sanitized_string}%") if sanitized_string.present?
  end

  def new
    @person = Person.new
  end

  def create
    @person = Current.user.people.build(person_params)
    if @person.save
      redirect_back fallback_location: people_path, notice: 'Person created'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    scoped_bullets = Current.user.bullets.joins(:people)
                            .where(people: { id: @person.id })
                            .where(archived: false)
                            .distinct
    scoped_bullets = scoped_bullets.where(bulletable_type: selected_type) if selected_type.present?
    @bullets = set_page_and_extract_portion_from(scoped_bullets, per_page: [5, 15, 30, 50])
  end

  def destroy
    @person.destroy
    redirect_back fallback_location: people_path, notice: 'Person deleted'
  end

  private

  def set_person
    @person = Current.user.people.find(params[:id])
  end

  def sanitized_string
    @sanitized_string ||= ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.strip.downcase)
  end

  def selected_type
    @selected_type ||= params[:type].to_s.classify.presence_in(Bullet.bulletable_types)
  end

  def person_params
    params.require(:person).permit(:name, :email, :number, :colour, :icon, :avatar)
  end
end
