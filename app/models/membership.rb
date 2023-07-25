# app/models/membership.rb
#
# Copyright (c) 2018 Banff International Research Station.
# This file is part of Workshops. Workshops is licensed under
# the GNU Affero General Public License as published by the
# Free Software Foundation, version 3 of the License.
# See the COPYRIGHT file for details and exceptions.
#
class Membership < ApplicationRecord
  attr_accessor :sync_memberships, :update_by_staff, :update_remote, :is_rsvp,
                :warn_guest

  belongs_to :event
  belongs_to :person
  accepts_nested_attributes_for :person
  has_one :invitation, dependent: :delete
  serialize :invite_reminders, Hash

  before_save :set_billing, :set_guests
  after_save :update_counter_cache
  after_update :notify_staff
  after_commit :sync_with_legacy
  before_destroy :delete_on_legacy
  after_destroy :update_counter_cache

  validates :event, presence: true
  validates :person, presence: true,
                     uniqueness: { scope: :event,
                                   message: 'is already a participant
                                   of this event'.squish }
  validates :updated_by, presence: true

  validate :set_role
  validate :default_attendance
  validate :check_max_participants
  validate :check_max_observers
  validate :arrival_and_departure_dates
  validate :guest_disclaimer_acknowledgement
  validate :has_address_if_confirmed, unless: :is_rsvp

  ROLES = ['Contact Organizer', 'Organizer', 'Virtual Organizer', 'Participant',
           'Virtual Participant', 'Observer', 'Backup Participant'].freeze

  ATTENDANCE = ['Confirmed', 'Invited', 'Undecided', 'Not Yet Invited',
                'Declined'].freeze

  INVITATION_ATTENDANCE = ['Invited', 'Undecided', 'Not Yet Invited'].freeze
  ONLINE_ROLES = ['Virtual Organizer', 'Virtual Participant'].freeze
  IN_PERSON_ROLES = ['Contact Organizer', 'Organizer', 'Participant'].freeze

  scope :confirmed, -> { where(attendance: 'Confirmed') }
  scope :invited, -> { where(attendance: 'Invited') }
  scope :undecided, -> { where(attendance: 'Undecided') }
  scope :not_yet_invited, -> { where(attendance: 'Not Yet Invited') }
  scope :declined, -> { where(attendance: 'Declined') }
  scope :in_person, -> { where(role: IN_PERSON_ROLES) }

  include SharedDecorators

  def shares_email?
    self.share_email
  end

  def arrives
    return 'Not set' if arrival_date.blank?
    arrival_date.strftime('%b %-d, %Y')
  end

  def departs
    return 'Not set' if departure_date.blank?
    departure_date.strftime('%b %-d, %Y')
  end

  def rsvp_date
    return 'N/A' if replied_at.blank?
    replied_at.in_time_zone(event.time_zone).strftime('%b %-d, %Y %H:%M %Z')
  end

  def organizer?
    role.include?('Organizer')
  end

  def contact_organizer?
    role == 'Contact Organizer'
  end

  def virtual_organizer?
    organizer? && virtual?
  end

  def participant?
    role.include?('Participant')
  end

  def virtual_participant?
    participant? && virtual?
  end

  def virtual?
    role.include?('Virtual')
  end

  def observer?
    role.include?('Observer')
  end

  private

  def set_billing
    return unless billing.blank? && !self.person.country.blank?
    country = is_usa?(self.person.country) ? 'USA' : self.person.country
    self.billing = GetSetting.billing_code(self.event.location, country)
  end

  def set_num_guests
    return 1 if has_guest && (num_guests.blank? || num_guests.to_i == 0)
    return 0 if has_guest === false
    num_guests
  end

  def set_guests
    self.warn_guest = true if has_guest === false && num_guests.to_i > 0
    self.num_guests = set_num_guests
  end

  def set_role
    unless ROLES.include?(role)
      self.role = 'Participant'
    end
  end

  def default_attendance
    unless Membership::ATTENDANCE.include?(attendance)
      self.attendance = 'Not Yet Invited'
    end
  end

  # max_participants - (invited + confirmed participants)
  def check_max_participants
    return if sync_memberships
    return if attendance == 'Declined' || attendance == 'Not Yet Invited'
    return if event_id.nil?
    return if role == 'Observer'
    return check_max_confirmed if attendance == 'Confirmed'
    return check_max_virtual if event.online? || role.match?('Virtual')

    max = event.max_participants
    invited = event.num_invited_participants
    invited -= event.num_invited_virtual if event.hybrid?
    field_name = 'attendance'

    # if the role changes from Virtual to Physical, ensure within max limit
    if role_changed?
      field_name = 'role'
      invited += 1 if role == 'Participant'
    end

    if invited > max
      errors.add(:"#{field_name}", "- the maximum number of invited participants
                (#{max}) for #{event.code} has been reached.".squish)
    end
    check_max_virtual if event.hybrid?
  end

  def check_max_confirmed
    event_full = false
    if role.include?('Virtual') || event.event_format == 'Online'
      event_full = event.num_confirmed_virtual >= event.max_virtual
    else
      event_full = event.num_confirmed_in_person >= event.max_participants
    end

    errors.add(:role, "- the maximum number of confirmed #{role.pluralize} has
               been reached.".squish) if event_full
  end

  def check_max_virtual
    max = event.max_virtual
    invited = event.num_invited_virtual
    field_name ="attendance"

    # if the role changes to Virtual, make sure we're in max_virtual limit
    if role_changed?
      field_name = "role"
      invited += 1 if role.match?('Virtual')
    end

    if invited > max
      errors.add(:"#{field_name}", "- the maximum number of invited Virtual
        Participants (#{max}) for #{event.code} has been
        reached.".squish)
    end
  end

  def check_max_observers
    return if sync_memberships
    return unless role == 'Observer'

    max = event.max_observers
    invited = event.num_invited_observers
    field_name ="attendance"

    if role_changed?
      field_name = "role"
      invited += 1
    end

    if invited > max
      errors.add(:"#{field_name}", "- the maximum number of invited observers
              (#{max}) for #{event.code} has been reached.".squish)
    end
  end

  def arrival_and_departure_dates
    return true if attendance == 'Declined'
    w = event
    unless arrival_date.blank?
      if arrival_date.to_date > w.end_date.to_date
        errors.add(:arrival_date,
                   '- arrival date must be before the end of the event.')
      end
      if (arrival_date.to_date - w.start_date.to_date).to_i.abs >= 30
        errors.add(:arrival_date,
                   '- arrival date must be within 30 days of the event.')
      end

      return if update_by_staff || sync_memberships
      if arrival_date.to_date < w.start_date.to_date
        errors.add(:arrival_date,
                   '- special permission required for early arrival.')
      end
    end

    unless departure_date.blank?
      if departure_date.to_date < w.start_date.to_date
        errors.add(:departure_date,
                   '- departure date must be after the beginning of the event.')
      end

      return if update_by_staff || sync_memberships
      if departure_date.to_date > w.end_date.to_date
        errors.add(:departure_date,
                   '- special permission required for late departure.')
      end
    end

    unless arrival_date.blank? || departure_date.blank?
      if arrival_date.to_date > departure_date.to_date
        errors.add(:arrival_date, "- one must arrive before departing!")
      end
    end
  end

  def guest_disclaimer_acknowledgement
    return if update_by_staff == true
    if has_guest && guest_disclaimer == false
      errors.add(:guest_disclaimer, "must be acknowledged if bringing a guest.")
    end
  end

  def organizer_address_error(field)
    errors.add(:person, "- #{field} is required for confirmed organizers")
  end

  def mailout_sent
    # BIRS requires mailing address only for April mailout, a year in advance
    self.event.start_date.year <= Date.today.year ||
      (self.event.start_date.year == Date.today.next_year.year &&
      Date.today.month > 4)
  end

  def org_address_fields
    country = person.country
    address_fields = %w(address1 city country postal_code)
    address_fields << 'region' if is_usa?(country) || country == 'Canada'
    address_fields
  end

  def has_full_address
    return true if mailout_sent
    org_address_fields.each do |field|
      organizer_address_error(field) if self.person.send(field.to_sym).blank?
    end
  end

  def has_address_if_confirmed
    return if self.person.nil?
    return true unless attendance == 'Confirmed'
    return has_full_address if role.match?(/Organizer/)
    if self.person.country.blank? && self.attendance == 'Confirmed'
      errors.add(:person, '- country must be set for confirmed members')
      self.person.errors.add(:country, :invalid)
    end
  end

  def update_counter_cache
    event.confirmed_count = Membership.where("attendance='Confirmed'
      AND event_id=?", event.id).count
    event.data_import = true
    event.save
  end

  def sync_with_legacy
    unless sync_memberships
      SyncMembershipJob.perform_later(id) if update_remote
    end
  end

  def delete_on_legacy
    member = { event_id: event.code, legacy_id: person.legacy_id,
               person_id: person_id, updated_by: updated_by }
    DeleteMembershipJob.perform_later(member) unless sync_memberships
  end

  def notify_staff
    changes = saved_changes.transform_values(&:first)
    MembershipChangeNotice.new(changes, self).run
  end
end
