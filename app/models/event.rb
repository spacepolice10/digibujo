class Event < ApplicationRecord
  include Cardable

  def temporal?
    true
  end

  def completable?
    true
  end

  def form_fields = [:date_picker, :ends_date_picker, :tags_picker]
end
