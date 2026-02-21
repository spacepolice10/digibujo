class Task < ApplicationRecord
  include Cardable

  def temporal?
    true
  end

  def completable?
    true
  end
end
