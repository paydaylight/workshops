class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead of :exception.
  protect_from_forgery with: :exception, unless: :json_request?
  protect_from_forgery with: :null_session, if: :json_request?
  skip_before_action :verify_authenticity_token, if: :json_request?

  rescue_from ActionController::InvalidAuthenticityToken, with: :invalid_auth_token
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
  rescue_from ActiveRecord::RecordNotSaved, with: :record_not_saved

  # Authorization module
  include Pundit
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  # Enforces access right checks for individuals resources
  #after_action :verify_authorized, :except => :index

  # Enforces access right checks for collections
  #after_action :verify_policy_scoped, :except => :index

  include ApplicationHelper

  before_action :set_paper_trail_whodunnit
  before_action :set_current_user, if: :json_request?
  before_action :configure_permitted_parameters, if: :devise_controller?

  add_flash_types :warning, :success, :info, :error

  def set_event
    event_id = validate_event_id
    @event = event_id.blank? ? nil : Event.find(event_id)
    redirect_to events_future_path, error: 'Invalid event id.' if @event.nil?
  end

  def set_time_zone
    Time.zone = @event.time_zone if @event && @event.time_zone
  end

  def set_attendance
    @attendance = Membership::ATTENDANCE unless @event.blank?
  end

  private

  def record_not_found
    redirect_to events_future_path, error: 'Record not found.'
  end

  def record_not_saved
    redirect_to :back, error: 'Something happened while saving record'
  end

  def authenticate_user!(*args)
    super and return unless args.blank?
    json_request? ? authenticate_api_user! : super
  end

  def validate_event_id
    event_id = (params[:event_id] || params[:id])
    return if event_id.blank?
    event_id if Event.where(id: event_id).or(Event.where(code: event_id)).exists?
  end

  def invalid_auth_token
    respond_to do |format|
      format.html { redirect_to sign_in_path, error: 'Login invalid or expired' }
      format.json { head 401 }
    end
  end

  def user_not_authorized(exception)
    policy_name = exception.policy.class.to_s.underscore

    respond_to do |format|
      format.html do
        flash[:error] = t "#{policy_name}.#{exception.query}",
                          scope: 'pundit', default: :default

        redirect_to request.referrer and return unless request.referrer.nil?
        redirect_to my_events_path and return
      end
      format.json { head 403 }
    end
  end

  # After successful login, redirect to attempted page or home page
  def after_sign_in_path_for(_resource)
    flash[:success] = 'Signed in successfully!' if flash.blank?
    stored_location_for(_resource) || home_path
  end

  def after_sign_out_path_for(_resource)
    sign_in_path
  end

  def json_request?
    request.format.json?
  end

  # Same Pundit policies for api_users
  def set_current_user
    @current_user ||= warden.authenticate(scope: :api_user)
  end

  def configure_permitted_parameters
    update_attrs = [:password, :password_confirmation, :current_password]
    devise_parameter_sanitizer.permit :account_update, keys: update_attrs
  end
end
