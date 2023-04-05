# frozen_string_literal: true

class DoubleCheckRSVPMailer < ApplicationMailer
  def remind(invitation_id:)
    @invitation = Invitation.find(invitation_id)
    @event = @invitation.membership.event

    subject = "Attendance confirmation of #{@event.code} at #{@event.location}"

    mail(to: [@invitation.person.to_email_address], subject: subject)
  end

  def alert_staff(event_id:)
    event = Event.find(event_id)

    to = event.staff_at_location.map(&:to_email_address)
    subject = "[#{event.code}] Participation Status"

    mail(to: to, subject: subject)
  end
end
