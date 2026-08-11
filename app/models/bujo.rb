class Bujo
  def initialize(user)
    @user = user
  end
  attr_reader :user

  def current_future
    user.futures.covering(Date.current).take
  end

  def current_monthlylog
    @user.monthlylogs.covering(Date.current).take
  end

  def current_daylog
    @user.daylog
  end

  def current_pending
    @user.pending
  end
end
