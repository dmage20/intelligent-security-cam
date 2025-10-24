require "test_helper"

class SceneAnalyzerTest < ActiveSupport::TestCase
  setup do
    # Create test camera
    @camera = Camera.create!(
      name: 'Test Camera',
      rtsp_url: 'rtsp://test.example.com/stream',
      active: true,
      capture_interval_seconds: 5
    )

    @timestamp = Time.current
    @image_path = Rails.root.join('test', 'fixtures', 'files', 'test_image.jpg').to_s

    # Create a minimal valid JPEG for testing
    FileUtils.mkdir_p(File.dirname(@image_path))
    @jpeg_data = "\xFF\xD8\xFF\xE0\x00\x10JFIF\x00\x01\x01\x00\x00\x01\x00\x01\x00\x00\xFF\xD9"
    File.binwrite(@image_path, @jpeg_data)

    # Sample successful API response
    @successful_api_response = {
      id: 'msg_123',
      type: 'message',
      role: 'assistant',
      content: [
        {
          type: 'text',
          text: {
            detected_objects: [
              {
                type: 'person',
                description: 'Person in dark clothing',
                position: { area: 'center', specifics: 'standing near door' },
                confidence: 0.95,
                likely_same_as_tracked: nil
              }
            ],
            scene_description: 'Person approaching front door',
            weather: {
              condition: 'clear',
              intensity: 'none',
              changed_from_previous: false
            },
            lighting: 'day',
            active_object_count: 1,
            change_magnitude: 45,
            reasoning: 'New person detected in frame, no previous tracking data'
          }.to_json
        }
      ],
      model: 'claude-sonnet-4-5',
      usage: { input_tokens: 1234, output_tokens: 567 }
    }.to_json

    # Set API key for tests
    ENV['ANTHROPIC_API_KEY'] = 'test-api-key-123'
  end

  teardown do
    File.delete(@image_path) if @image_path && File.exist?(@image_path)
    ENV.delete('ANTHROPIC_API_KEY')
  end

  # === Input Validation Tests ===

  test "raises ArgumentError when image_path is nil" do
    error = assert_raises(ArgumentError) do
      SceneAnalyzer.analyze_comprehensive(nil, @camera, @timestamp)
    end
    assert_match /image_path cannot be nil/, error.message
  end

  test "raises ArgumentError when camera is nil" do
    error = assert_raises(ArgumentError) do
      SceneAnalyzer.analyze_comprehensive(@image_path, nil, @timestamp)
    end
    assert_match /camera cannot be nil/, error.message
  end

  test "raises ArgumentError when timestamp is nil" do
    error = assert_raises(ArgumentError) do
      SceneAnalyzer.analyze_comprehensive(@image_path, @camera, nil)
    end
    assert_match /timestamp cannot be nil/, error.message
  end

  test "raises ArgumentError when camera is not a Camera instance" do
    error = assert_raises(ArgumentError) do
      SceneAnalyzer.analyze_comprehensive(@image_path, "not a camera", @timestamp)
    end
    assert_match /camera must be a Camera instance/, error.message
  end

  # === API Key Tests ===

  test "raises AuthenticationError when API key is not set" do
    ENV.delete('ANTHROPIC_API_KEY')

    error = assert_raises(SceneAnalyzer::AuthenticationError) do
      SceneAnalyzer.analyze_comprehensive(@image_path, @camera, @timestamp)
    end
    assert_match /ANTHROPIC_API_KEY not set/, error.message
  end

  test "uses ENV variable for API key over database Setting" do
    Setting.set('anthropic_api_key', 'database-key')
    ENV['ANTHROPIC_API_KEY'] = 'env-key'

    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .with(headers: { 'x-api-key' => 'env-key' })
      .to_return(status: 200, body: @successful_api_response)

    SceneAnalyzer.analyze_comprehensive(@image_path, @camera, @timestamp)

    assert_requested :post, "https://api.anthropic.com/v1/messages",
                     headers: { 'x-api-key' => 'env-key' }
  end

  test "falls back to database Setting when ENV not set" do
    ENV.delete('ANTHROPIC_API_KEY')
    Setting.set('anthropic_api_key', 'database-key')

    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .with(headers: { 'x-api-key' => 'database-key' })
      .to_return(status: 200, body: @successful_api_response)

    SceneAnalyzer.analyze_comprehensive(@image_path, @camera, @timestamp)

    assert_requested :post, "https://api.anthropic.com/v1/messages",
                     headers: { 'x-api-key' => 'database-key' }
  end

  # === Image Encoding Tests ===

  test "raises InvalidImageError when image file does not exist" do
    error = assert_raises(SceneAnalyzer::InvalidImageError) do
      SceneAnalyzer.analyze_comprehensive('/nonexistent/image.jpg', @camera, @timestamp)
    end
    assert_match /Image file not found/, error.message
  end

  test "raises InvalidImageError when file is not a valid JPEG" do
    invalid_image = Rails.root.join('test', 'fixtures', 'files', 'invalid.jpg').to_s
    File.write(invalid_image, "not a jpeg")

    error = assert_raises(SceneAnalyzer::InvalidImageError) do
      SceneAnalyzer.analyze_comprehensive(invalid_image, @camera, @timestamp)
    end
    assert_match /not a valid JPEG/, error.message
  ensure
    File.delete(invalid_image) if File.exist?(invalid_image)
  end

  test "encodes image to base64 correctly" do
    encoded = SceneAnalyzer.send(:encode_image, @image_path)

    assert encoded.is_a?(String)
    assert_equal Base64.strict_encode64(@jpeg_data), encoded
    # Verify it's valid base64
    assert_nothing_raised { Base64.strict_decode64(encoded) }
  end

  # === API Call Tests ===

  test "successful API call returns parsed analysis" do
    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_return(status: 200, body: @successful_api_response)

    result = SceneAnalyzer.analyze_comprehensive(@image_path, @camera, @timestamp)

    assert_equal 'Person approaching front door', result[:scene_description]
    assert_equal 'day', result[:lighting]
    assert_equal 1, result[:detected_objects].length
    assert_equal 'person', result[:detected_objects].first[:type]
    assert_equal 'clear', result[:weather][:condition]
    assert result[:reasoning].present?
  end

  test "sends correct request format to Anthropic API" do
    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_return(status: 200, body: @successful_api_response)

    SceneAnalyzer.analyze_comprehensive(@image_path, @camera, @timestamp)

    assert_requested :post, "https://api.anthropic.com/v1/messages" do |req|
      body = JSON.parse(req.body)
      body['model'] == 'claude-sonnet-4-5' &&
        body['max_tokens'] == 2048 &&
        body['messages'].first['content'].first['type'] == 'image' &&
        body['messages'].first['content'].first['source']['type'] == 'base64' &&
        body['messages'].first['content'].last['type'] == 'text'
    end
  end

  test "includes camera name and timestamp in prompt" do
    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_return(status: 200, body: @successful_api_response)

    SceneAnalyzer.analyze_comprehensive(@image_path, @camera, @timestamp)

    assert_requested :post, "https://api.anthropic.com/v1/messages" do |req|
      body = JSON.parse(req.body)
      prompt = body['messages'].first['content'].last['text']
      prompt.include?(@camera.name) && prompt.include?(@timestamp.strftime('%Y-%m-%d'))
    end
  end

  # === Context Building Tests ===

  test "includes previous scene state in prompt when available" do
    previous_state = SceneState.create!(
      camera: @camera,
      timestamp: @timestamp - 7.seconds,
      overall_description: 'Empty scene',
      lighting: 'day',
      weather: { condition: 'clear' },
      active_object_count: 0
    )

    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_return(status: 200, body: @successful_api_response)

    SceneAnalyzer.analyze_comprehensive(@image_path, @camera, @timestamp)

    assert_requested :post, "https://api.anthropic.com/v1/messages" do |req|
      body = JSON.parse(req.body)
      prompt = body['messages'].first['content'].last['text']
      prompt.include?('PREVIOUS SCENE') && prompt.include?('Empty scene')
    end
  end

  test "includes currently tracked objects in prompt" do
    tracked_obj = TrackedObject.create!(
      camera: @camera,
      object_type: 'package',
      identifier: 'pkg_001',
      status: 'present',
      first_detected_at: @timestamp - 3.hours,
      last_detected_at: @timestamp - 5.seconds,
      appearance_description: 'Brown box'
    )

    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_return(status: 200, body: @successful_api_response)

    SceneAnalyzer.analyze_comprehensive(@image_path, @camera, @timestamp)

    assert_requested :post, "https://api.anthropic.com/v1/messages" do |req|
      body = JSON.parse(req.body)
      prompt = body['messages'].first['content'].last['text']
      prompt.include?('CURRENTLY TRACKED OBJECTS') &&
        prompt.include?('package') &&
        prompt.include?('pkg_001')
    end
  end

  test "includes active routines in prompt" do
    routine = Routine.create!(
      camera: @camera,
      name: 'Morning dog walk',
      description: 'Person walks dog every morning',
      active: true,
      confidence_score: 85,
      time_pattern: { hour_range: [7, 8], days_of_week: [1, 2, 3, 4, 5] },
      frequency: 'weekdays',
      occurrence_count: 15,
      first_seen_at: @timestamp - 30.days,
      last_seen_at: @timestamp - 1.day
    )

    # Set timestamp to match routine time (7:30 AM on a Monday)
    test_timestamp = Time.current.beginning_of_week + 7.hours + 30.minutes

    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_return(status: 200, body: @successful_api_response)

    SceneAnalyzer.analyze_comprehensive(@image_path, @camera, test_timestamp)

    assert_requested :post, "https://api.anthropic.com/v1/messages" do |req|
      body = JSON.parse(req.body)
      prompt = body['messages'].first['content'].last['text']
      prompt.include?('LEARNED PATTERNS') && prompt.include?('Morning dog walk')
    end
  end

  # === Error Handling Tests ===

  test "raises AuthenticationError on 401 response" do
    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_return(status: 401, body: '{"error": "invalid_api_key"}')

    error = assert_raises(SceneAnalyzer::AuthenticationError) do
      SceneAnalyzer.analyze_comprehensive(@image_path, @camera, @timestamp)
    end
    assert_match /Invalid API key/, error.message
  end

  test "raises RateLimitError on 429 response" do
    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_return(
        status: 429,
        headers: { 'retry-after' => '60' },
        body: '{"error": "rate_limit_exceeded"}'
      )

    error = assert_raises(SceneAnalyzer::RateLimitError) do
      SceneAnalyzer.analyze_comprehensive(@image_path, @camera, @timestamp)
    end
    assert_match /Rate limit exceeded/, error.message
    assert_match /60s/, error.message
  end

  test "raises AnalysisError on 400 bad request" do
    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_return(status: 400, body: '{"error": "invalid_request"}')

    error = assert_raises(SceneAnalyzer::AnalysisError) do
      SceneAnalyzer.analyze_comprehensive(@image_path, @camera, @timestamp)
    end
    assert_match /Bad request/, error.message
  end

  test "raises AnalysisError on 500 server error" do
    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_return(status: 500, body: 'Internal server error')

    error = assert_raises(SceneAnalyzer::AnalysisError) do
      SceneAnalyzer.analyze_comprehensive(@image_path, @camera, @timestamp)
    end
    assert_match /API error \(HTTP 500\)/, error.message
  end

  test "raises AnalysisError on network timeout" do
    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_timeout

    error = assert_raises(SceneAnalyzer::AnalysisError) do
      SceneAnalyzer.analyze_comprehensive(@image_path, @camera, @timestamp)
    end
    assert_match /timeout|Network error/, error.message
  end

  test "raises AnalysisError on connection refused" do
    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_raise(Errno::ECONNREFUSED)

    error = assert_raises(SceneAnalyzer::AnalysisError) do
      SceneAnalyzer.analyze_comprehensive(@image_path, @camera, @timestamp)
    end
    assert_match /Network error/, error.message
  end

  # === Response Parsing Tests ===

  test "handles Claude response wrapped in markdown code blocks" do
    markdown_response = {
      content: [
        {
          type: 'text',
          text: "```json\n#{JSON.parse(@successful_api_response).dig('content', 0, 'text')}\n```"
        }
      ]
    }.to_json

    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_return(status: 200, body: markdown_response)

    result = SceneAnalyzer.analyze_comprehensive(@image_path, @camera, @timestamp)

    assert result[:scene_description].present?
    assert result[:detected_objects].present?
  end

  test "raises AnalysisError when response missing required fields" do
    incomplete_response = {
      content: [
        {
          type: 'text',
          text: { detected_objects: [], scene_description: 'test' }.to_json
        }
      ]
    }.to_json

    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_return(status: 200, body: incomplete_response)

    error = assert_raises(SceneAnalyzer::AnalysisError) do
      SceneAnalyzer.analyze_comprehensive(@image_path, @camera, @timestamp)
    end
    assert_match /missing required fields/, error.message
  end

  test "raises AnalysisError when response is not valid JSON" do
    invalid_json_response = {
      content: [
        { type: 'text', text: 'This is not JSON' }
      ]
    }.to_json

    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_return(status: 200, body: invalid_json_response)

    error = assert_raises(SceneAnalyzer::AnalysisError) do
      SceneAnalyzer.analyze_comprehensive(@image_path, @camera, @timestamp)
    end
    assert_match /Failed to parse Claude's JSON response/, error.message
  end
end
