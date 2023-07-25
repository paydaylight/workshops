# frozen_string_literal: true

module InvitationMailerContext
  extend ActiveSupport::Concern

  attr_reader :membership, :invitation, :person, :event

  def liquid_context
    @liquid_context ||= {
      'person_dear_name' => person.dear_name,
      'person_affiliation' => person.affiliation,
      'person_role' => membership.role,
      'invitation_date' => invitation.invited_on.strftime('%A, %B %-d, %Y'),
      'invitation_code' => invitation.code,
      'event_name' => event.name,
      'event_location' => event.location,
      'event_code' => event.code,
      'rsvp_url' => invitation.rsvp_url,
      'rsvp_deadline' => RsvpDeadline.new(event, DateTime.current, membership).rsvp_by,
      'event_start' => event.start_date_formatted,
      'event_end' => event.end_date_formatted,
      'event_url' => event.url,
      'organizers' => PersonWithAffilList.compose(event.organizers),
      'is_organizer' => membership.organizer?,
      'is_contact_organizer' => membership.contact_organizer?,
      'is_virtual_organizer' => membership.virtual_organizer?,
      'is_participant' => membership.participant?,
      'is_virtual_participant' => membership.virtual_participant?,
      'is_observer' => membership.observer?
    }
  end
end
