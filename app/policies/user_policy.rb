# frozen_string_literal: true
class UserPolicy
  attr_reader :current_user

  def initialize(current_user, _current_user)
    @current_user = current_user
  end

  def admin?
    return false unless current_user

    current_user.is_admin?
  end
end
