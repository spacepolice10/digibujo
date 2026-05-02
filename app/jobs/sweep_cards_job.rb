class SweepCardsJob < ApplicationJob
  def perform
    Bullet.auto_archivable.where(archives_on: nil).update_all(archived: true, archives_on: Date.current)
    Bullet.auto_archivable.where.not(archives_on: nil).update_all(archived: true)
    Bullet.expired_archived.destroy_all
  end
end
