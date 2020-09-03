# Copyright (c) 2018 Banff International Research Station.
# This file is part of Workshops. Workshops is licensed under
# the GNU Affero General Public License as published by the
# Free Software Foundation, version 3 of the License.
# See the COPYRIGHT file for details and exceptions.

# Griddler class for processing incoming email
class EmailProcessor
  attr_accessor :valid_email

  def initialize(email)
    @email = email
  end

  def process
    return if @email.nil? || skip_vacation_notices

    extract_recipients.each do |list_params|
      EventMaillist.new(@email, list_params).send_message
    end
  end

  private

  def skip_vacation_notices
    subject = @email.subject.downcase
    subject.match?("bounce notice") || subject.match?("out of office") ||
      subject.match?("vacation notice") || subject.match?("away notice")
  end

  # assembles valid maillists from To:, Cc:, Bcc: fields
  def extract_recipients
    maillists = []
    invalid_sender = false
    recipients = @email.to + @email.cc + @email.bcc
    problem = ''

    recipients.each do |recipient|
      # Skip Outlook webmaster=webmaster@ auto-replies
      return [] if recipient[:full].match?(/(.+)=(.+)@/)
      to_email, code, group = extract_recipient(recipient)

      unless code.match?(/#{GetSetting.code_pattern}/)
        problem = 'Event code does not match valid code pattern.'
      else
        event = Event.find(code)
        if event.blank?
          problem = 'Event with given code not found.'
        else
          if valid_sender?(event, to_email, group)
            maillists << {
              event: event,
              group: member_group(group),
              destination: to_email
            }
          else
            invalid_sender = true
          end
        end
      end
    end

    if maillists.empty? && !invalid_sender
      EmailInvalidCodeBounceJob.perform_later(email_params)
      send_report({ problem: problem, recipients: recipients })
    end

    maillists
  end

  def extract_recipient(recipient)
    to_email = recipient[:email]
    code = recipient[:token] # part before the @
    group = 'Confirmed'
    code, group = code.split('-') if code.match?(/-/)
    return [to_email, code, group]
  end

  def member_group(group)
    group.downcase!
    return 'orgs' if group == 'orgs' || group == 'organizers'
    return 'all' if group == 'all'
    return 'speakers' if group == 'speakers'

    Membership::ATTENDANCE.each do |status|
      return status if group.titleize == status
    end
  end

  def valid_sender?(event, to_email, group)
    from_email = @email.from[:email].downcase.strip
    unless EmailValidator.valid?(from_email)
      Rails.logger.debug "\n\n*** Invalid from email: #{from_email}\n\n"
      send_report({ problem: "From: email is invalid: #{from_email}" })
      return false
    end
    person = Person.find_by_email(from_email)

    return true if organizers_and_staff(event).include?(person)

    params = email_params.merge(event_code: event.code, to: to_email)
    unless event.confirmed.include?(person)
      EmailFromNonmemberBounceJob.perform_later(params)
      return false
    end

    return true if allowed_group?(group)
    UnauthorizedSubgroupBounceJob.perform_later(params)
    return false
  end

  # groups that Confirmed participants (non-organizers) may send to
  def allowed_group?(group)
    %w(confirmed all orgs organizers).include?(group.downcase)
  end

  def organizers_and_staff(event)
    event.organizers + event.staff
  end

  def send_report(problem = nil)
    msg = {
            problem: 'Unknown',
            email_params: email_params,
            email_object: @email.inspect
          }
    msg.merge!(problem) unless problem.nil?
    StaffMailer.notify_sysadmin(@event, msg).deliver_now
  end

  def email_recipients
    @email.to.map {|e| e[:email] } + @email.cc.map {|e| e[:email] }
  end

  def email_params
    {
      to: email_recipients,
      from: @email.from[:full],
      subject: @email.subject,
      body: @email.body,
      date: @email.headers['Date']
    }
  end
end
