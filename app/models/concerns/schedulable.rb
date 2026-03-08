module Schedulable
  extend ActiveSupport::Concern
  include Promotable

  def schedule_as_task!(attrs = {})
    promote_to! Task.new
  end
end
