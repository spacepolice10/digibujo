class SweepCardsJob < ApplicationJob
  def perform
    Card.auto_archivable.update_all(archived: true)
    Card.expired_archived.destroy_all
  end
end
