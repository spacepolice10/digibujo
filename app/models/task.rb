class Task < ApplicationRecord
  include Cardable

  def temporal?
    true
  end

  def completable?
    true
  end

  def form_fields = [:date_picker, :tag_picker]
end
