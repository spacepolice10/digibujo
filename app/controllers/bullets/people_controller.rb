# frozen_string_literal: true

class Bullets::PeopleController < ApplicationController
  include PrepareBullets

  before_action :prepare_bullets

  def new
    @q = sanitized_query
    @people = Current.user.people.order(:name)
    @people = @people.where("name LIKE ?", "#{@q}%") if @q.present?
  end

  def create
    @source_buckets = @bullets.to_h { |bullet| [bullet.id, bullet.bucket] }
    person_id = params.require(:person_id)
    Bullet.transaction do
      @bullets.lock.find_each { |bullet| bullet.tag_person!(person_id: person_id) }
    end
    @bullets.each(&:reload)
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back fallback_location: daylog_path(date: daylog_redirect_date.iso8601) }
    end
  rescue ActiveRecord::RecordInvalid => e
    @failed_bullet = e.record
    respond_to do |format|
      format.turbo_stream { render :create, status: :unprocessable_entity }
      format.html do
        redirect_back fallback_location: daylog_path(date: daylog_redirect_date.iso8601),
                      alert: e.record.errors.full_messages.to_sentence
      end
    end
  end

  def destroy
    @source_buckets = @bullets.to_h { |bullet| [bullet.id, bullet.bucket] }
    Bullet.transaction do
      @bullets.lock.find_each(&:untag_all_people!)
    end
    @bullets.each(&:reload)
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back fallback_location: daylog_path(date: daylog_redirect_date.iso8601) }
    end
  rescue ActiveRecord::RecordInvalid => e
    @failed_bullet = e.record
    respond_to do |format|
      format.turbo_stream { render :destroy, status: :unprocessable_entity }
      format.html do
        redirect_back fallback_location: daylog_path(date: daylog_redirect_date.iso8601),
                      alert: e.record.errors.full_messages.to_sentence
      end
    end
  end

  private

  def sanitized_query
    @sanitized_query ||= ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.strip.downcase)
  end
end
