# frozen_string_literal: true

class EventStatisticsMailer < ApplicationMailer
  def notify(event_id:)
    @event = Event.find(event_id)

    @confirmed_count = Membership.confirmed.where(event: @event).count
    @invited_count = Membership.invited.where(event: @event).count
    @undecided_count = Membership.undecided.where(event: @event).count
    @not_yet_invited_count = Membership.not_yet_invited.where(event: @event).count
    @declined_count = Membership.declined.where(event: @event).count

    recipients = []

    @event.organizers.each do |organizer|
      recipients << to_email_address(organizer)
    end

    User.admins.each do |admin|
      recipients << to_email_address(admin)
    end

    subject = I18n.t('email.event_statistics.subject', event_code: @event.code)

    mail(to: recipients.join(', '), subject: subject)
  end
end
