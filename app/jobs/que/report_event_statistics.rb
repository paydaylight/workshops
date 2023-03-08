# frozen_string_literal: true

module Que
  class ReportEventStatistics < Job
    def run(event_id:)
      event = Event.find(event_id)

      EventStatisticsMailer.notify(event_id: event_id)
    ensure
      reschedule_job(event)
    end

    def reschedule_job(event)
      next_run = 2.month.from_now(Date.today.in_time_zone(event.time_zone)).beginning_of_day

      return if event.start_date_in_time_zone < next_run

      self.class.enqueue(event_id: event.id, job_options: { run_at: next_run })
    end
  end
end
