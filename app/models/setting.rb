class Setting < ApplicationRecord
  # Validations
  validates :key, presence: true, uniqueness: true

  # Class methods for easy access
  def self.get(key, default = nil)
    find_by(key: key)&.value || default
  end

  def self.set(key, value, description = nil)
    setting = find_or_initialize_by(key: key)
    setting.value = value.to_s
    setting.description = description if description
    setting.save!
  end

  def self.anthropic_api_key
    get('anthropic_api_key')
  end

  def self.event_similarity_window_minutes
    get('event_similarity_window', 30).to_i
  end

  def self.routine_min_occurrences
    get('routine_min_occurrences', 5).to_i
  end

  def self.routine_confidence_threshold
    get('routine_confidence_threshold', 80).to_f
  end

  def self.image_retention_days
    get('image_retention_days', 30).to_i
  end
end
