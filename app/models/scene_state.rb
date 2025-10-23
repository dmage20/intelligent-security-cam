class SceneState < ApplicationRecord
  # Associations
  belongs_to :camera
  has_many :observations, dependent: :nullify

  # Validations
  validates :timestamp, presence: true

  # Scopes
  scope :recent, -> { order(timestamp: :desc) }
  scope :today, -> { where('timestamp >= ?', Time.current.beginning_of_day) }

  # Methods
  def is_raining?
    weather.dig('condition') == 'raining'
  end

  def is_daytime?
    lighting&.in?(%w[day dawn dusk])
  end
end
