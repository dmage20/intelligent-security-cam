class Camera < ApplicationRecord
  # Associations
  has_many :tracked_objects, dependent: :destroy
  has_many :observations, dependent: :destroy
  has_many :scene_states, dependent: :destroy
  has_many :routines, dependent: :destroy
  has_many :conversation_memories, dependent: :destroy

  # Validations
  validates :name, presence: true
  validates :rtsp_url, presence: true, format: { with: /\Artsp:\/\//i, message: "must be a valid RTSP URL" }
  validates :capture_interval_seconds, numericality: { greater_than: 0, less_than_or_equal_to: 3600 }

  # Scopes
  scope :active, -> { where(active: true) }

  # Methods
  def current_tracked_objects
    tracked_objects.where(status: 'present')
  end

  def recent_observations(limit = 50)
    observations.order(occurred_at: :desc).limit(limit)
  end
end
