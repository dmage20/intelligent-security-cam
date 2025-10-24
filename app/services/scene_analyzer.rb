# frozen_string_literal: true

require 'httparty'
require 'base64'

# SceneAnalyzer sends camera frames to Claude Vision API for intelligent analysis
#
# Provides contextual awareness by including:
# - Previous SceneState (what was happening 5 seconds ago)
# - Currently tracked objects (persistent object tracking)
# - Active routines (learned patterns for this time of day)
#
# Returns structured analysis including detected objects, scene description,
# weather conditions, lighting, and Claude's reasoning process.
#
class SceneAnalyzer
  class AnalysisError < StandardError; end
  class AuthenticationError < StandardError; end
  class RateLimitError < StandardError; end
  class InvalidImageError < StandardError; end

  ANTHROPIC_API_URL = 'https://api.anthropic.com/v1/messages'
  ANTHROPIC_VERSION = '2023-06-01'
  MODEL = 'claude-sonnet-4-5'  # Claude Sonnet 4.5 (latest)
  MAX_TOKENS = 2048

  # Analyzes a camera frame with full contextual awareness
  #
  # @param image_path [String] Path to the JPEG image file
  # @param camera [Camera] Camera model instance
  # @param timestamp [Time] When the frame was captured
  # @return [Hash] Structured analysis with keys:
  #   - detected_objects: Array of {type, description, position, confidence}
  #   - scene_description: Overall description of what's happening
  #   - weather: Hash with {condition, intensity, changed}
  #   - lighting: String (day/night/dawn/dusk)
  #   - reasoning: Claude's thought process
  #
  def self.analyze_comprehensive(image_path, camera, timestamp)
    validate_inputs!(image_path, camera, timestamp)

    api_key = get_api_key
    image_data = encode_image(image_path)

    # Gather contextual information
    previous_state = get_previous_scene_state(camera, timestamp)
    tracked_objects = get_current_tracked_objects(camera)
    active_routines = get_active_routines(camera, timestamp)

    # Build the contextual prompt
    prompt = build_comprehensive_prompt(
      previous_state: previous_state,
      tracked_objects: tracked_objects,
      active_routines: active_routines,
      camera: camera,
      timestamp: timestamp
    )

    # Call Claude Vision API
    response = call_anthropic_api(api_key, image_data, prompt)

    # Parse and return structured response
    parse_response(response)
  rescue Errno::ENOENT
    raise InvalidImageError, "Image file not found: #{image_path}"
  rescue JSON::ParserError => e
    raise AnalysisError, "Failed to parse API response: #{e.message}"
  end

  private

  def self.validate_inputs!(image_path, camera, timestamp)
    raise ArgumentError, "image_path cannot be nil" if image_path.nil?
    raise ArgumentError, "camera cannot be nil" if camera.nil?
    raise ArgumentError, "timestamp cannot be nil" if timestamp.nil?
    raise ArgumentError, "camera must be a Camera instance" unless camera.is_a?(Camera)
  end

  def self.get_api_key
    # Try environment variable first (recommended for security)
    api_key = ENV['ANTHROPIC_API_KEY']

    # Fallback to database Setting if ENV not set
    api_key ||= Setting.anthropic_api_key

    if api_key.nil? || api_key.empty?
      raise AuthenticationError,
            "ANTHROPIC_API_KEY not set. Set ENV['ANTHROPIC_API_KEY'] or use Setting.set('anthropic_api_key', 'your-key')"
    end

    api_key
  end

  def self.encode_image(image_path)
    image_bytes = File.binread(image_path)

    # Verify it's a JPEG by checking magic bytes
    unless image_bytes.start_with?("\xFF\xD8".b)
      raise InvalidImageError, "File is not a valid JPEG image"
    end

    Base64.strict_encode64(image_bytes)
  end

  def self.get_previous_scene_state(camera, timestamp)
    # Look for scene state from ~5 seconds ago (within 3-10 seconds range)
    camera.scene_states
          .where('timestamp < ?', timestamp)
          .where('timestamp >= ?', timestamp - 10.seconds)
          .order(timestamp: :desc)
          .first
  end

  def self.get_current_tracked_objects(camera)
    camera.tracked_objects.present.includes(:observations)
  end

  def self.get_active_routines(camera, timestamp)
    # Get high-confidence routines (>80%) that match current time
    camera.routines
          .active
          .high_confidence
          .select { |routine| routine.matches_time?(timestamp) }
  end

  def self.build_comprehensive_prompt(previous_state:, tracked_objects:, active_routines:, camera:, timestamp:)
    prompt_parts = []

    # Base instruction
    prompt_parts << "You are analyzing a security camera frame. Provide a detailed analysis in JSON format."
    prompt_parts << ""
    prompt_parts << "Camera: #{camera.name}"
    prompt_parts << "System Time: #{timestamp.strftime('%Y-%m-%d %I:%M:%S %p')}"
    prompt_parts << ""
    prompt_parts << "IMPORTANT: Determine lighting (day/night/dawn/dusk) by ANALYZING THE IMAGE VISUALLY."
    prompt_parts << "Do NOT infer lighting from the system time - the clock may be incorrect."

    # Previous scene context
    if previous_state
      prompt_parts << ""
      prompt_parts << "PREVIOUS SCENE (~5 seconds ago):"
      prompt_parts << "- Description: #{previous_state.overall_description}" if previous_state.overall_description
      prompt_parts << "- Lighting: #{previous_state.lighting}" if previous_state.lighting
      prompt_parts << "- Weather: #{previous_state.weather['condition']}" if previous_state.weather.present?
      prompt_parts << "- Active objects: #{previous_state.active_object_count}"
    end

    # Currently tracked objects
    if tracked_objects.any?
      prompt_parts << ""
      prompt_parts << "CURRENTLY TRACKED OBJECTS:"
      tracked_objects.each do |obj|
        duration = obj.duration_human
        prompt_parts << "- #{obj.object_type} (#{obj.identifier}): Present for #{duration}"
        prompt_parts << "  Description: #{obj.appearance_description}" if obj.appearance_description
      end
      prompt_parts << ""
      prompt_parts << "IMPORTANT: Check if these same objects are still visible in the current frame."
    end

    # Active routines
    if active_routines.any?
      prompt_parts << ""
      prompt_parts << "LEARNED PATTERNS (Routines for this time):"
      active_routines.each do |routine|
        prompt_parts << "- #{routine.name} (#{routine.confidence_score.to_i}% confidence)"
        prompt_parts << "  #{routine.description}" if routine.description
      end
      prompt_parts << ""
      prompt_parts << "Note: These are normal recurring events. Only flag as notable if something is different."
    end

    # Response format instructions
    prompt_parts << ""
    prompt_parts << "Analyze the current frame and respond with JSON in this exact format:"
    prompt_parts << '{'
    prompt_parts << '  "detected_objects": ['
    prompt_parts << '    {'
    prompt_parts << '      "type": "person|vehicle|package|pet|other",'
    prompt_parts << '      "description": "Brief visual description",'
    prompt_parts << '      "position": {"area": "left|center|right|background", "specifics": "near door, on porch, etc"},'
    prompt_parts << '      "confidence": 0.95,'
    prompt_parts << '      "likely_same_as_tracked": "identifier or null if new object"'
    prompt_parts << '    }'
    prompt_parts << '  ],'
    prompt_parts << '  "scene_description": "Overall description of what is happening",'
    prompt_parts << '  "weather": {'
    prompt_parts << '    "condition": "clear|cloudy|raining|snowing|foggy",'
    prompt_parts << '    "intensity": "none|light|moderate|heavy",'
    prompt_parts << '    "changed_from_previous": true/false'
    prompt_parts << '  },'
    prompt_parts << '  "lighting": "day|night|dawn|dusk",'
    prompt_parts << '  "active_object_count": number,'
    prompt_parts << '  "change_magnitude": 0-100 (how much changed from previous scene),'
    prompt_parts << '  "reasoning": "Your thought process and notable observations"'
    prompt_parts << '}'

    prompt_parts.join("\n")
  end

  def self.call_anthropic_api(api_key, image_data, prompt)
    response = HTTParty.post(
      ANTHROPIC_API_URL,
      headers: {
        'x-api-key' => api_key,
        'anthropic-version' => ANTHROPIC_VERSION,
        'content-type' => 'application/json'
      },
      body: {
        model: MODEL,
        max_tokens: MAX_TOKENS,
        messages: [
          {
            role: 'user',
            content: [
              {
                type: 'image',
                source: {
                  type: 'base64',
                  media_type: 'image/jpeg',
                  data: image_data
                }
              },
              {
                type: 'text',
                text: prompt
              }
            ]
          }
        ]
      }.to_json,
      timeout: 30
    )

    handle_api_errors(response)

    response
  rescue Net::OpenTimeout, Net::ReadTimeout => e
    raise AnalysisError, "API request timeout: #{e.message}"
  rescue SocketError, Errno::ECONNREFUSED => e
    raise AnalysisError, "Network error: #{e.message}"
  end

  def self.handle_api_errors(response)
    return if response.success?

    case response.code
    when 401
      raise AuthenticationError, "Invalid API key: #{response.body}"
    when 429
      error_body = JSON.parse(response.body) rescue {}
      retry_after = response.headers['retry-after'] || 'unknown'
      raise RateLimitError, "Rate limit exceeded. Retry after: #{retry_after}s. #{error_body['error']}"
    when 400
      error_body = JSON.parse(response.body) rescue {}
      raise AnalysisError, "Bad request: #{error_body['error']}"
    else
      raise AnalysisError, "API error (HTTP #{response.code}): #{response.body}"
    end
  end

  def self.parse_response(response)
    body = JSON.parse(response.body)

    # Extract the text content from Claude's response
    content = body.dig('content', 0, 'text')

    if content.nil?
      raise AnalysisError, "Unexpected API response format: missing content"
    end

    # Parse the JSON from Claude's text response
    # Claude sometimes wraps JSON in markdown code blocks, so clean it
    json_text = content.strip
    json_text = json_text.gsub(/^```json\s*/, '').gsub(/```$/, '').strip

    analysis = JSON.parse(json_text, symbolize_names: true)

    # Validate required fields
    required_fields = [:detected_objects, :scene_description, :weather, :lighting, :reasoning]
    missing_fields = required_fields - analysis.keys

    if missing_fields.any?
      raise AnalysisError, "Response missing required fields: #{missing_fields.join(', ')}"
    end

    analysis
  rescue JSON::ParserError => e
    raise AnalysisError, "Failed to parse Claude's JSON response: #{e.message}\nContent: #{content}"
  end
end
