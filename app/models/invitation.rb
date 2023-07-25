# app/models/invitation.rb
#
# Copyright (c) 2018 Banff International Research Station.
# This file is part of Workshops. Workshops is licensed under
# the GNU Affero General Public License as published by the
# Free Software Foundation, version 3 of the License.
# See the COPYRIGHT file for details and exceptions.

class Invitation < ApplicationRecord
  belongs_to :membership
  attr_accessor :organizer_message

  validates :membership, :invited_by, presence: true
  validates :code, presence: true, length: { is: 50 }

  after_initialize :generate_code
  before_save :update_times

  def generate_code
    self.code = SecureRandom.urlsafe_base64(37) if self.code.blank?
  end

  def send_invite
    update_and_save

    EmailInvitationJob.perform_later(id, initial_email: membership.attendance == 'Not Yet Invited')
  end

  def set_invitation_template
    self.templates = InvitationTemplateSelector.new(membership).set_templates
    return true if File.exist?(self.templates['text_template_file'])

    subject = "[#{event.code}] invitation template missing!"
    error_msg = { problem: 'Participant invitation not sent.',
                  cause: 'Email template missing.',
                  template: self.templates['text_template_file'],
                  recipient: "#{person.name} <#{person.email}>",
                  attendance: membership.attendance,
                  person: person.inspect,
                  membership: membership.inspect,
                  invitation: self.inspect }
    StaffMailer.notify_program_coord(event, subject, error_msg).deliver_now
    self.templates = nil
    false
  end

  def send_reminder
    update_reminder
    EmailInvitationJob.perform_later(id)
  end

  def expire_date
    expires.strftime("%B %-d, %Y")
  end

  def event
    membership.event
  end

  def person
    membership.person
  end

  def rsvp_url
    GetSetting.app_url + '/rsvp/' + self.code
  end

  def accept
    update_membership('Confirmed')
    EmailParticipantConfirmationJob.perform_later(membership.id)
    destroy
  end

  def decline
    update_membership('Declined')
    destroy
  end

  def maybe
    update_membership('Undecided')
  end

  def virtual?
    self.membership.role == 'Virtual Participant'
  end

  def self.invalid_rsvp_setting
    Setting.Site.blank? || Setting.Site['rsvp_expiry'].blank? ||
      !Setting.Site['rsvp_expiry'].match?(/\A\d+\.\w+$/)
  end

  def self.duration_setting
    return 3.days if invalid_rsvp_setting

    parts = Setting.Site['rsvp_expiry'].split('.')
    parts.first.to_i.send(parts.last)
  end

  # Invitations expire EXPIRES_BEFORE an event starts
  EXPIRES_BEFORE = duration_setting

  def update_times
    self.invited_on = DateTime.current
    if membership.event.online? || membership.virtual?
      self.expires = event.end_date_in_time_zone.end_of_day
    else
      start_time = event.start_date_in_time_zone.beginning_of_day
      self.expires = start_time - EXPIRES_BEFORE
    end
  end

  def email_template_path
    InvitationEmailPathBuilder.build_path(
      event_location: membership.event.location,
      event_type: membership.event.event_type,
      event_format: membership.event.event_format,
      attendance: membership.attendance
    )
  end

  private

  def update_and_save
    membership.sent_invitation = true
    membership.invited_by = invited_by
    membership.invited_on = DateTime.current
    membership.update_remote = true
    membership.is_rsvp = true # don't resend organizer notice
    membership.person.member_import = true
    if membership.attendance == 'Not Yet Invited'
      membership.arrival_date = nil
      membership.departure_date = nil
      membership.role = 'Participant' if membership.role == 'Backup Participant'
      membership.updated_by = invited_by
    end
    membership.save!
    save
  end

  def update_reminder
    reminders = membership.invite_reminders
    reminders[DateTime.current] = invited_by
    membership.update_columns(invite_reminders: reminders)
  end

  def update_membership_fields(status)
    membership.attendance = status
    membership.replied_at = DateTime.current
    membership.updated_by = membership.person.name
  end

  def update_person_fields(status)
    if status == 'Confirmed'
      membership.person.updated_by = membership.person.name
    else
      membership.person.member_import = true # skip validations
    end
  end

  def email_organizer(status)
    args = { 'attendance_was' => membership.attendance,
             'attendance' => status,
             'organizer_message' => organizer_message }
    EmailOrganizerNoticeJob.perform_later(membership.id, args)
  end

  def log_rsvp(status)
    Rails.logger.info "\n\n*** RSVP: #{membership.person.name}
    (#{membership.person_id}) is now #{status} for
    #{membership.event.code} ***\n\n".squish
  end

  def update_membership(status)
    email_organizer(status)
    log_rsvp(status)
    update_membership_fields(status)
    update_person_fields(status)
    membership.update_remote = true
    membership.is_rsvp = true
    begin
      membership.save!
    rescue ActiveRecord::RecordInvalid => error
      params = { 'error' => error.to_s, 'membership' => membership.inspect }
      EmailFailedRsvpJob.perform_later(membership.id, params)
    end
  end
end
