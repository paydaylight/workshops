# frozen_string_literal: true

class EventStatisticsMailer < ApplicationMailer
  def notify(event_id:)
    @event = Event.find(event_id)

    @confirmed_count = Membership.in_person.confirmed.where(event: @event).count
    @invited_count = Membership.in_person.invited.where(event: @event).count
    @undecided_count = Membership.in_person.undecided.where(event: @event).count
    @physical_spots = @event.max_participants - @confirmed_count - @invited_count - @undecided_count
    @virtual_spots = @event.max_virtual - @event.num_invited_virtual

    return if @physical_spots.zero?

    recipients = []

    @event.organizers.each do |organizer|
      recipients << to_email_address(organizer)
    end

    @event.staff_at_location.each do |staff|
      recipients << to_email_address(staff)
    end

    subject = I18n.t('email.event_statistics.subject', location: @event.location, event_code: @event.code)

    mail(to: recipients.join(', '), subject: subject)
  end
end
