# frozen_string_literal: true

module UserEmailUtils
  extend ActiveSupport::Concern

  def to_email_address
    "\"#{name}\" <#{email}>"
  end
end
