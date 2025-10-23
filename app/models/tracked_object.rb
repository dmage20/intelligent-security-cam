class TrackedObject < ApplicationRecord
  # Associations
  belongs_to :camera
  has_many :observation_tracked_objects, dependent: :destroy
  has_many :observations, through: :observation_tracked_objects

  # Validations
  validates :object_type, presence: true
  validates :identifier, presence: true, uniqueness: true
  validates :status, inclusion: { in: %w[present disappeared uncertain] }
  validates :first_detected_at, :last_detected_at, presence: true

  # Scopes
  scope :present, -> { where(status: 'present') }
  scope :disappeared, -> { where(status: 'disappeared') }
  scope :by_type, ->(type) { where(object_type: type) }

  # Callbacks
  before_save :calculate_duration

  # Methods
  def calculate_duration
    if last_detected_at && first_detected_at
      self.duration_minutes = ((last_detected_at - first_detected_at) / 60).to_i
    end
  end

  def mark_disappeared!
    update!(status: 'disappeared', disappeared_at: Time.current)
  end

  def update_last_seen!
    update!(last_detected_at: Time.current)
    calculate_duration
    save!
  end

  def duration_human
    return "Just appeared" if duration_minutes < 1

    hours = duration_minutes / 60
    minutes = duration_minutes % 60

    if hours > 0
      "#{hours}h #{minutes}m"
    else
      "#{minutes}m"
    end
  end
end
