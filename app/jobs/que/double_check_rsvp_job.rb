# frozen_string_literal: true

module Que
  class DoubleCheckRSVPJob < Job
    def run(event_id:, step: :rsvp_one_month_before_event)
      @event = Event.find(event_id)

      case step
      when :rsvp_one_month_before_event
        rsvp_one_month_before_event
      when :rsvp_two_weeks_before_event
        rsvp_two_weeks_before_event
      when :alert_staff
        alert_staff
      else
        notify_sysadmin('Unknown step', step: step)
      end
    rescue StandardError => e
      notify_sysadmin(e.message, step: step, error_object: e)
    end

    private

    attr_reader :event

    def rsvp_one_month_before_event
      send_emails if today_in_event_tz < event.two_weeks_before_start

      enqueue_step(step: :rsvp_two_weeks_before_event, run_at: event.two_weeks_before_start)
    end

    def rsvp_two_weeks_before_event
      send_emails if today_in_event_tz <= event.start_date_in_time_zone

      enqueue_step(step: :alert_staff, run_at: event.one_week_before_start)
    end

    def alert_staff
      return if email_group.count.zero?

      DoubleCheckRSVPMailer.alert_staff(event_id: event.id).deliver_now
    end

    def enqueue_step(step:, run_at:)
      self.class.enqueue(event_id: event.id, step: step, job_options: { run_at: run_at })
    end

    def notify_sysadmin(message, step: nil, error_object: nil)
      error_msg = {
        problem: message,
        event_code: event&.code,
        step: step,
        backtrace: error_object&.backtrace
      }
      StaffMailer.notify_sysadmin(event, error_msg).deliver_now
    end

    def send_emails
      email_group.each do |invitation|
        DoubleCheckRSVPMailer.remind(invitation_id: invitation.id).deliver_now
      end
    end

    def email_group
      Invitation.joins(:membership).where(memberships: { attendance: 'Confirmed', role: Membership::IN_PERSON_ROLES })
      # event.memberships.joins(:invitation).confirmed.where(role: Membership::IN_PERSON_ROLES)
    end

    def today_in_event_tz
      Date.today.in_time_zone(event.time_zone)
    end
  end
end
