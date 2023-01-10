require 'administrate/field/select'

class SelectLocationField < Administrate::Field::Select
  def to_partial_path
    "/fields/#{Administrate::Field::Select.field_type}/#{page}"
  end

  private

  # This will make sure that events with edited/deleted locations show accurate data
  def collection
    super.unshift(data).uniq
  end
end
