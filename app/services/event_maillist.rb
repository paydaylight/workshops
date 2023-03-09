# Copyright (c) 2018 Banff International Research Station.
# This file is part of Workshops. Workshops is licensed under
# the GNU Affero General Public License as published by the
# Free Software Foundation, version 3 of the License.
# See the COPYRIGHT file for details and exceptions.

# Receives Griddler:Email object, distributes message to destination
class EventMaillist
  include Sendable

  ORGANIZERS_GROUP = %w[orgs organizers].freeze
  SPEAKERS_GROUP = %w[speakers].freeze
  ALL_GROUP = %w[all].freeze
  ATTENDANCE_GROUP = Membership::ATTENDANCE
  ATTENDANCE_SUB_GROUPS = %w[in_person online].freeze

  def initialize(email, mailist_params)
    @email       = email
    @event       = mailist_params[:event]
    @group       = mailist_params[:group]
    @subgroup    = mailist_params[:subgroup]
    @destination = mailist_params[:destination]
  end

  def send_message
    return if already_sent?(@destination)
    subject = @email.subject
    subject = "[#{@event.code}] #{subject}" unless subject.include?(@event.code)
    email_parts = EmailParser.new(@email, @destination, @event).parse

    message = {
      location: @event.location,
      from: @email.from[:full],
      to: @destination,
      subject: subject,
      email_parts: email_parts,
      attachments: @email.attachments,
    }

    if ORGANIZERS_GROUP.include?(@group)
      send_to_orgs(message)
    elsif ALL_GROUP.include?(@group)
      send_to_all(message)
    elsif SPEAKERS_GROUP.include?(@group)
      send_to_speakers(message)
    elsif ATTENDANCE_GROUP.include?(@group) && ATTENDANCE_SUB_GROUPS.include?(@subgroup)
      send_to_attendance_subgroup(message)
    elsif ATTENDANCE_GROUP.include?(@group)
      send_to_attendance_group(message)
    else
      return report_unknown_group(message)
    end

    record_sent_mail(subject, @destination)
  end

  def remove_trailing_comma(str)
    str.blank? ? '' : str.chomp(",")
  end

  def send_to_orgs(message)
    to = ''
    @event.contact_organizers.each do |org|
      to << %Q("#{org.name}" <#{org.email}>, )
    end
    to = remove_trailing_comma(to)
    cc = ''
    @event.supporting_organizers.each do |org|
      cc << %Q("#{org.name}" <#{org.email}>, )
    end
    cc = remove_trailing_comma(cc)
    recipients = { to: to, cc: cc }

    if ENV['APPLICATION_HOST'].include?('staging')
      recipients = { to: GetSetting.site_email('webmaster_email'), cc: '' }
    end

    begin
      resp = MaillistMailer.workshop_organizers(message, recipients).deliver_now
    rescue
      StaffMailer.notify_sysadmin(@event.id, resp).deliver_now
    end
  end

  def send_to_all(message)
    ['Confirmed', 'Invited', 'Undecided'].each do |status|
      @group = status
      send_to_attendance_group(message)
    end
  end

  def send_to_speakers(message)
    @event.lectures.each do |lecture|
      email_member(lecture.person, message)
    end
  end

  def send_to_attendance_group(message)
    if @group == 'Not Yet Invited'
      members = @event.attendance(@group) - @event.role('Backup Participant')
      members.each do |member|
        email_member(member, message)
      end
    else
      @event.attendance(@group).each do |member|
        email_member(member, message)
      end
    end
  end

  def send_to_attendance_subgroup(message)
    roles = {
      'in_person' => Membership::IN_PERSON_ROLES,
      'online' => Membership::ONLINE_ROLES
    }

    members = @event.attendance_and_role(role: roles[@subgroup], attendance: @group)
    members.each do |member|
      email_member(member, message)
    end
  end

  def email_member(member, message)
    if member.is_a?(Person)
      recipient = %Q("#{member.name}" <#{member.email}>)
    else
      recipient = %Q("#{member.person.name}" <#{member.person.email}>)
    end

    if ENV['APPLICATION_HOST'].include?('staging')
      recipient = GetSetting.site_email('webmaster_email')
    end

    begin
      resp = MaillistMailer.workshop_maillist(message, recipient).deliver_now
    rescue
      msg = { problem: 'MaillistMailer.workshop_maillist failed.',
              recipient: recipient,
              response: resp,
              message: message
            }
      StaffMailer.notify_sysadmin(@event.id, msg).deliver_now
    end
  end

  def report_unknown_group(message)
    msg = {
      problem: "Don't know how to send to group '#{@group}'",
      email_object: @email.inspect,
      message: message
    }

    StaffMailer.notify_sysadmin(@event.id, msg).deliver_now
  end
end
