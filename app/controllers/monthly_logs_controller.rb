class MonthlyLogsController < ApplicationController
  def show
    monthly_log = Current.user.bullets.monthly_log(Date.current)
    @bullets = set_page_and_extract_portion_from(
      monthly_log,
    per_page: [5, 15, 30, 50]
  )
end
end