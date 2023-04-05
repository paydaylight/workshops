# frozen_string_literal: true

module EventRSVP
  extend ActiveSupport::Concern

  def two_weeks_before_start
    2.weeks.before(start_date_in_time_zone)
  end

  def one_week_before_start
    1.week.before(start_date_in_time_zone)
  end
end
