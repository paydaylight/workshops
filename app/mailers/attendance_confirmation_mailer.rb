# frozen_string_literal: true

class AttendanceConfirmationMailer < ApplicationMailer
  def remind(invitation_id:)
    @invitation = Invitation.find(invitation_id)
    @event = @invitation.membership.event

    @program_coordinator = GetSetting.email(@event.location, 'program_coordinator')

    subject = "[#{@event.code}] Attendance confirmation"

    mail(to: [@invitation.person.to_email_address], subject: subject)
  end

  def alert_staff(event_id:)
    @event = Event.find(event_id)
    membership_ids = Invitation.no_rsvp_from_confirmed.with_event(event_id: event_id).pluck(:membership_id)
    @no_shows_count = membership_ids.size
    @no_shows_emails = Person.joins(:memberships).where(memberships: { id: membership_ids }).pluck(:email)

    to = @event.staff_at_location.map(&:to_email_address)
    subject = "[#{@event.code}] Participation status"

    mail(to: to, subject: subject)
  end
end
