# frozen_string_literal: true

class AttendanceConfirmationMailerPreview < ActionMailer::Preview
  def remind
    AttendanceConfirmationMailer.remind(invitation_id: Invitation.last.id)
  end
end
