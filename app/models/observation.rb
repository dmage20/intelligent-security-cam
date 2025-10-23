class Observation < ApplicationRecord
  # Associations
  belongs_to :camera
  belongs_to :scene_state, optional: true
  belongs_to :routine, optional: true
  has_many :observation_tracked_objects, dependent: :destroy
  has_many :tracked_objects, through: :observation_tracked_objects

  # Validations
  validates :occurred_at, presence: true
  validates :notification_priority, inclusion: { in: %w[none low medium high urgent] }

  # Scopes
  scope :recent, -> { order(occurred_at: :desc) }
  scope :routine, -> { where(is_routine: true) }
  scope :not_routine, -> { where(is_routine: false) }
  scope :notified, -> { where(notification_sent: true) }
  scope :today, -> { where('occurred_at >= ?', Time.current.beginning_of_day) }
  scope :priority, ->(level) { where(notification_priority: level) }

  # Methods
  def should_notify?
    notification_priority != 'none' && !notification_sent
  end

  def detected_object_types
    detected_objects.map { |obj| obj['type'] || obj[:type] }.compact.uniq
  end

  def has_object_type?(type)
    detected_object_types.include?(type.to_s)
  end
end
