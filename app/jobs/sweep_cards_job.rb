class SweepCardsJob < ApplicationJob
  def perform
    Card.auto_archivable.where(archives_on: nil).update_all(archived: true, archives_on: Date.today)
    Card.auto_archivable.where.not(archives_on: nil).update_all(archived: true)
    Card.expired_archived.destroy_all
  end
end
