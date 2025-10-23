class Routine < ApplicationRecord
  # Associations
  belongs_to :camera
  has_many :observations, dependent: :nullify

  # Validations
  validates :name, presence: true
  validates :confidence_score, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :frequency, inclusion: { in: %w[daily weekdays weekly specific_days] }, allow_nil: true

  # Scopes
  scope :active, -> { where(active: true) }
  scope :high_confidence, -> { where('confidence_score >= ?', 80) }
  scope :auto_suppressing, -> { where(auto_suppress: true) }

  # Methods
  def matches_time?(timestamp)
    return false unless time_pattern.present?

    hour = timestamp.hour
    day_of_week = timestamp.wday

    hour_matches = time_pattern['hour_range'].nil? ||
                   hour.between?(time_pattern['hour_range'][0], time_pattern['hour_range'][1])

    day_matches = time_pattern['days_of_week'].nil? ||
                  time_pattern['days_of_week'].include?(day_of_week)

    hour_matches && day_matches
  end

  def increment_occurrence!
    update!(
      occurrence_count: occurrence_count + 1,
      last_seen_at: Time.current
    )
  end
end
