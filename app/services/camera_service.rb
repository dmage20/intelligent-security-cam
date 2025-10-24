# frozen_string_literal: true

require 'httparty'

# CameraService handles frame capture from cameras via Agent DVR HTTP API
#
# Agent DVR acts as a proxy, connecting to RTSP cameras and exposing HTTP snapshots.
# This solves macOS 26 beta security restrictions that block direct RTSP access.
#
# Prerequisites:
#   - Agent DVR must be installed and running (http://localhost:8090)
#   - Camera must be added to Agent DVR with an object ID (oid)
#
# Usage:
#   camera = Camera.first
#   image_path = CameraService.capture_frame(camera_id: camera.id, agent_dvr_oid: 1)
#   # => "storage/events/camera_1_20241024_154530.jpg"
#
class CameraService
  class CaptureError < StandardError; end
  class ConnectionError < StandardError; end
  class InvalidParameterError < StandardError; end

  # Agent DVR configuration
  AGENT_DVR_HOST = 'localhost'
  AGENT_DVR_PORT = 8090
  AGENT_DVR_URL = "http://#{AGENT_DVR_HOST}:#{AGENT_DVR_PORT}"

  # Capture a single frame from a camera via Agent DVR
  #
  # @param agent_dvr_oid [Integer] The Agent DVR object ID (oid) for the camera
  # @param output_path [String, nil] Optional output path. If nil, generates timestamped filename
  # @param camera_id [Integer, nil] Optional camera ID for filename generation
  # @return [String] Full path to the captured image file
  # @raise [InvalidParameterError] if agent_dvr_oid is invalid
  # @raise [ConnectionError] if unable to connect to Agent DVR
  # @raise [CaptureError] for other errors
  def self.capture_frame(agent_dvr_oid:, output_path: nil, camera_id: nil)
    validate_agent_dvr_oid!(agent_dvr_oid)

    output_path ||= generate_output_path(camera_id)
    ensure_output_directory!(output_path)

    snapshot_url = "#{AGENT_DVR_URL}/grab.jpg?oid=#{agent_dvr_oid}"

    Rails.logger.info("CameraService: Capturing frame from Agent DVR (oid: #{agent_dvr_oid})")

    begin
      # Fetch snapshot from Agent DVR
      response = HTTParty.get(snapshot_url, timeout: 10)

      unless response.success?
        raise ConnectionError, "Agent DVR returned error: HTTP #{response.code}"
      end

      unless response.headers['content-type']&.include?('image/jpeg')
        raise CaptureError, "Invalid response from Agent DVR: expected JPEG, got #{response.headers['content-type']}"
      end

      # Save image to file
      File.binwrite(output_path, response.body)

      unless File.exist?(output_path)
        raise CaptureError, "Frame saved but output file not found: #{output_path}"
      end

      file_size = File.size(output_path)
      Rails.logger.info("CameraService: Successfully captured frame (#{file_size} bytes) to #{output_path}")

      output_path
    rescue HTTParty::Error => e
      raise ConnectionError, "Cannot connect to Agent DVR at #{AGENT_DVR_URL}: #{e.message}"
    rescue Errno::ECONNREFUSED
      raise ConnectionError, "Agent DVR is not running at #{AGENT_DVR_URL}. Please start Agent DVR."
    rescue StandardError => e
      Rails.logger.error("CameraService: Unexpected error: #{e.class} - #{e.message}")
      raise CaptureError, "Failed to capture frame: #{e.message}"
    end
  end

  # Generate a timestamped output path for captured frames
  #
  # @param camera_id [Integer, nil] Optional camera ID
  # @return [String] Full path to output file
  def self.generate_output_path(camera_id = nil)
    timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
    camera_prefix = camera_id ? "camera_#{camera_id}" : "camera"
    filename = "#{camera_prefix}_#{timestamp}.jpg"

    Rails.root.join('storage', 'events', filename).to_s
  end

  # Validate Agent DVR object ID
  #
  # @param agent_dvr_oid [Integer] The Agent DVR object ID
  # @raise [InvalidParameterError] if oid is invalid
  def self.validate_agent_dvr_oid!(agent_dvr_oid)
    if agent_dvr_oid.nil?
      raise InvalidParameterError, "Agent DVR object ID (oid) cannot be nil"
    end

    unless agent_dvr_oid.is_a?(Integer) && agent_dvr_oid > 0
      raise InvalidParameterError, "Invalid Agent DVR object ID: #{agent_dvr_oid}"
    end
  end

  # Ensure output directory exists
  #
  # @param output_path [String] The full output file path
  def self.ensure_output_directory!(output_path)
    directory = File.dirname(output_path)
    FileUtils.mkdir_p(directory) unless File.directory?(directory)
  end

  private_class_method :validate_agent_dvr_oid!, :ensure_output_directory!
end
