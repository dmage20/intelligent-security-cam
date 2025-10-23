class ObservationTrackedObject < ApplicationRecord
  # Associations
  belongs_to :observation
  belongs_to :tracked_object

  # Validations
  validates :state_in_frame, inclusion: { in: %w[appeared present disappeared moved] }, allow_nil: true
end
