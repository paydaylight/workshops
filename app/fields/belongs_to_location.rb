require 'administrate/field/belongs_to'

class BelongsToLocation < Administrate::Field::BelongsTo
  def self.field_type
    'belongs_to'
  end

  private

  def candidate_resources
    scope = Location.including_id(data)

    order = options.delete(:order)
    order ? scope.reorder(order) : scope
  end
end
