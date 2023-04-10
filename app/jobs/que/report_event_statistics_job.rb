# frozen_string_literal: true

module Que
  class ReportEventStatisticsJob < Job
    def run(event_id:)
      event = Event.find(event_id)

      EventStatisticsMailer.notify(event_id: event_id).deliver_now

      schedule_job(event)
    end

    def schedule_job(event)
      next_run = next_run_at(event)

      return if event.start_date_in_time_zone < next_run

      self.class.enqueue(event_id: event.id, job_options: { run_at: next_run }) if event.present?
    end

    def next_run_at(event)
      if ::Rails.env.development?
        development_run_at(event)
      else
        production_run_at(event)
      end
    end

    def production_run_at(event)
      2.month.from_now(Date.today.in_time_zone(event.time_zone)).beginning_of_day
    end

    def development_run_at(event)
      1.hour.from_now(DateTime.now.in_time_zone(event.time_zone))
    end
  end
end
