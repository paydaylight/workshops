# Copyright (c) 2016 Banff International Research Station.
# This file is part of Workshops. Workshops is licensed under
# the GNU Affero General Public License as published by the
# Free Software Foundation, version 3 of the License.
# See the COPYRIGHT file for details and exceptions.

class RsvpController < ApplicationController
  before_action :set_invitation, except: %i[feedback]
  before_action :after_selection, except: %i[index confirm_attendance feedback]
  before_action :set_rsvp_page_variables, only: %i[index confirm_attendance]

  # GET /rsvp/:otp
  def index; end

  # GET /rsvp/confirm/:otp
  def confirm_attendance
    # Invitation code is probably not valid
    return unless @invitation.respond_to?(:membership)

    membership = @invitation.membership

    redirect_to rsvp_path(otp: otp_params) unless membership.attendance_requires_confirmation?
  end

  # GET /rsvp/email/:otp
  # POST /rsvp/email/:otp
  def email
    @person = @invitation.membership.person
    @email_form = EmailForm.new(@person)

    if request.post? && @email_form.validate_email(email_param)
      redirect_to set_yes_path(@invitation.membership.event),
                  success: 'E-mail updated/confirmed -- thanks!' and return
    end

    render 'confirm_email' and return if @person.pending_replacement?

    SyncMember.new(@invitation.membership, is_rsvp: true)
  end

  # GET /rsvp/confirm_email/:otp
  # POST /rsvp/confirm_email/:otp
  def confirm_email
    @person = Person.find_by_id(confirm_email_params['person_id']) ||
              @invitation.membership.person

    @email_form = EmailForm.new(@person)
    if @email_form.verify_email_change(confirm_email_params)
      redirect_to set_yes_path(@invitation.membership.event),
                  success: 'E-mail updated! Thank you.' and return
    end
  end

  # GET /rsvp/cancel/:otp
  def cancel
    person = @invitation.membership.person
    ConfirmEmailChange.where(replace_person_id: person.id,
                             replace_email: person.email).destroy_all
    if ConfirmEmailChange.where(replace_person_id: person.id,
                                replace_email: person.email).empty?
      redirect_to rsvp_email_path(otp: otp_params),
                  success: 'E-mail change cancelled.'
    else
      redirect_to rsvp_email_path(otp: otp_params),
                  error: 'Unable to cancel e-mail change :(.'
    end
  end

  # GET /rsvp/yes/:otp
  # POST /rsvp/yes/:otp
  def yes
    @rsvp = RsvpForm.new(@invitation.reload)
    @years = (1930..Date.current.year).to_a.reverse
    set_default_dates

    update_and_redirect(rsvp: :accept) if request.post? && @rsvp.validate_form(yes_params)
  end

  # GET /rsvp/yes-online/:otp
  # POST /rsvp/yes-online/:otp
  def yes_online
    @rsvp = RsvpForm.new(@invitation.reload)
    @years = (1930..Date.current.year).to_a.reverse

    return update_and_redirect(rsvp: :accept) if request.post? && @rsvp.validate_form(yes_params)

    render 'yes-online'
  end

  # To double-check confirmed members' attendance
  # POST /rsvp/yes-confirm/:otp
  def yes_confirm
    update_and_redirect(rsvp: :confirm_attendance)
  end

  # GET /rsvp/no/:otp
  # POST /rsvp/no/:otp
  def no
    update_and_redirect(rsvp: :decline) if request.post?
  end

  # GET /rsvp/maybe/:otp
  # POST /rsvp/maybe/:otp
  def maybe
    update_and_redirect(rsvp: :maybe) if request.post?
  end

  # GET /rsvp/feedback
  # POST /rsvp/feedback
  def feedback
    return unless request.post?

    membership = Membership.find_by_id(feedback_params[:membership_id])
    message = feedback_params[:feedback_message]
    EmailSiteFeedbackJob.perform_later('RSVP', membership.id, message) unless message.blank?
    redirect_to post_feedback_url(membership),
                success: 'Thanks for the feedback!'
  end

  private

  def set_rsvp_page_variables
    return unless @invitation.event.present?

    @event = @invitation.event
    @location = GetSetting.org_name(@event.location)
    @program_coordinator = GetSetting.email(@event.location, 'program_coordinator')
  end

  def post_feedback_url(membership)
    user = User.find_by_email(membership.person.email)
    return new_user_registration_path if user.nil?

    sign_in_path
  end

  def set_organizer_message
    @organizer_message = if params[:rsvp].blank?
                           ''
                         else
                           message_params['organizer_message']
                         end
  end

  def set_default_dates
    m = @invitation.membership
    m.arrival_date = m.event.start_date if m.arrival_date.blank?
    m.departure_date = m.event.end_date if m.departure_date.blank?
  end

  def update_and_redirect(rsvp:)
    @invitation.organizer_message = @organizer_message
    @invitation.send(rsvp) # sent to Invitation model

    redirect_to rsvp_feedback_path(@invitation.membership_id), success: 'Your attendance
      status was successfully updated. Thanks for your reply!'.squish
  end

  def set_invitation
    if params[:otp].blank?
      redirect_to invitations_new_path
    else
      # Returns an Invitation object, if one is found with given otp
      @invitation = InvitationChecker.new(otp_params).invitation
    end
  end

  def after_selection
    set_organizer_message
    @invitation.errors.any? ? redirect_to(rsvp_otp_path) : set_organizer
  end

  def set_organizer
    @organizer = @invitation.membership.event.organizer.name
  end

  def otp_params
    params[:otp].tr('^A-Za-z0-9_-', '')
  end

  def message_params
    params.require(:rsvp).permit(:organizer_message)
  end

  def feedback_params
    params.permit(:membership_id, :feedback_message)
  end

  def yes_params
    params.require(:rsvp).permit(
      membership: %i[arrival_date departure_date
                     own_accommodation has_guest guest_disclaimer special_info
                     share_email share_email_hotel role],
      person: [:salutation, :firstname, :lastname, :gender,
               :affiliation, :department, :title, :academic_status, :phd_year, :email,
               :url, :phone, :address1, :address2, :address3, :city, :region,
               :postal_code, :country, :emergency_contact, :emergency_phone,
               :biography, :research_areas, grants: []]
    )
  end

  def email_param
    params.require(:email_form).permit(person: [:email])
  end

  def confirm_email_params
    params.require(:email_form).permit(:person_id, :replace_email_code,
                                       :replace_with_email_code)
  end

  def set_yes_path(event)
    path_param = { otp: otp_params }
    return rsvp_yes_online_path(path_param) if event.online? || @invitation.virtual?

    rsvp_yes_path(path_param)
  end
end
