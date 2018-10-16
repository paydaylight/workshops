# Copyright (c) 2018 Banff International Research Station.
# This file is part of Workshops. Workshops is licensed under
# the GNU Affero General Public License as published by the
# Free Software Foundation, version 3 of the License.
# See the COPYRIGHT file for details and exceptions.

# Receives Griddler:Email object, distributes message to confirmed members
class EventMaillist
  def initialize(email, event, group)
    @email = email
    @event = event
    @group = group
    Rails.logger.debug "\n\n" + '*' * 100 + "\n\n"
    Rails.logger.debug "@email.to: #{@email.to.inspect}\n\n"
    Rails.logger.debug "\n\n" + '*' * 100 + "\n\n"
  end

  def send_message
    subject = @email.subject
    subject = "[#{@event.code}] #{subject}" unless subject.include?(@event.code)
    email_parts = EmailParser.new(@email, @event.code).parse

    message = {
      from: @email.to[0][:email],
      subject: @email.subject,
      email_parts: email_parts,
      attachments: @email.attachments,
    }

    if @group == 'orgs' || @group == 'organizers'
      send_to_orgs(message)
    else
      send_to_attendance_group(message)
    end
  end

  def send_to_orgs(message)
    @event.organizers.each do |member|
      email_member(member, message)
    end
  end

  def send_to_attendance_group(message)
    @event.attendance(@group).each do |member|
      email_member(member, message)
    end
  end

  def email_member(member, message)
    if member.is_a?(Membership)
      recipient = %Q("#{member.person.name}" <#{member.person.email}>)
    else
      recipient = %Q("#{member.name}" <#{member.email}>)
    end
    if ENV['APPLICATION_HOST'].include?('staging') && @event.code !~ /666/
      recipient = GetSetting.site_email('webmaster_email')
    end

    resp = MaillistMailer.workshop_maillist(message, recipient).deliver_now!

    if !resp.nil? && resp['total_rejected_recipients'] != 0
      StaffMailer.notify_sysadmin(@event.id, resp).deliver_now
    end
  end
end
