class ConversationMemory < ApplicationRecord
  # Associations
  belongs_to :camera

  # Validations
  validates :question, presence: true
  validates :question_type, inclusion: {
    in: %w[object_identification duration_query environmental_query anomaly_detection routine_query historical_query general_query]
  }, allow_nil: true

  # Scopes
  scope :recent, -> { order(asked_at: :desc) }
  scope :by_type, ->(type) { where(question_type: type) }
  scope :high_confidence, -> { where('confidence_in_answer >= ?', 70) }

  # Methods
  def confident?
    confidence_in_answer && confidence_in_answer >= 70
  end
end
