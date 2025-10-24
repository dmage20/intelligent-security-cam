require "test_helper"

class CameraServiceTest < ActiveSupport::TestCase
  setup do
    @valid_agent_dvr_oid = 3
    @valid_camera_id = 1
    @agent_dvr_url = "http://localhost:8090"
    @snapshot_url = "#{@agent_dvr_url}/grab.jpg?oid=#{@valid_agent_dvr_oid}"

    # Sample JPEG image data (minimal valid JPEG)
    @jpeg_data = "\xFF\xD8\xFF\xE0\x00\x10JFIF\x00\x01\x01\x00\x00\x01\x00\x01\x00\x00\xFF\xD9"
  end

  teardown do
    # Clean up test images
    Dir.glob(Rails.root.join('storage', 'events', 'camera_*_*.jpg')).each do |file|
      File.delete(file) if File.exist?(file)
    end
  end

  test "successful frame capture returns file path" do
    stub_request(:get, @snapshot_url)
      .to_return(
        status: 200,
        body: @jpeg_data,
        headers: { 'Content-Type' => 'image/jpeg' }
      )

    result = CameraService.capture_frame(
      agent_dvr_oid: @valid_agent_dvr_oid,
      camera_id: @valid_camera_id
    )

    assert result.is_a?(String), "Should return a string file path"
    assert File.exist?(result), "File should exist at returned path"
    assert result.include?('camera_1_'), "Path should include camera ID"
    assert result.end_with?('.jpg'), "Path should end with .jpg"
  end

test "successful frame capture saves JPEG file" do
    stub_request(:get, @snapshot_url)
      .to_return(
        status: 200,
        body: @jpeg_data,
        headers: { 'Content-Type' => 'image/jpeg' }
      )

    result = CameraService.capture_frame(
      agent_dvr_oid: @valid_agent_dvr_oid,
      camera_id: @valid_camera_id
    )

    file_content = File.binread(result)
    assert_equal @jpeg_data.b, file_content, "File should contain the exact JPEG data"
  end

  test "raises InvalidParameterError when agent_dvr_oid is nil" do
    error = assert_raises(CameraService::InvalidParameterError) do
      CameraService.capture_frame(
        agent_dvr_oid: nil,
        camera_id: @valid_camera_id
      )
    end

    assert_match /cannot be nil/, error.message
  end

  test "raises InvalidParameterError when agent_dvr_oid is zero" do
    error = assert_raises(CameraService::InvalidParameterError) do
      CameraService.capture_frame(
        agent_dvr_oid: 0,
        camera_id: @valid_camera_id
      )
    end

    assert_match /Invalid Agent DVR object ID/, error.message
  end

  test "raises InvalidParameterError when agent_dvr_oid is negative" do
    error = assert_raises(CameraService::InvalidParameterError) do
      CameraService.capture_frame(
        agent_dvr_oid: -1,
        camera_id: @valid_camera_id
      )
    end

    assert_match /Invalid Agent DVR object ID/, error.message
  end

  test "raises InvalidParameterError when agent_dvr_oid is not an integer" do
    error = assert_raises(CameraService::InvalidParameterError) do
      CameraService.capture_frame(
        agent_dvr_oid: "three",
        camera_id: @valid_camera_id
      )
    end

    assert_match /Invalid Agent DVR object ID/, error.message
  end

  test "raises CaptureError when Agent DVR returns 404" do
    stub_request(:get, @snapshot_url)
      .to_return(status: 404)

    error = assert_raises(CameraService::CaptureError) do
      CameraService.capture_frame(
        agent_dvr_oid: @valid_agent_dvr_oid,
        camera_id: @valid_camera_id
      )
    end

    assert_match /HTTP 404/, error.message
  end

  test "raises CaptureError when Agent DVR returns 500" do
    stub_request(:get, @snapshot_url)
      .to_return(status: 500)

    error = assert_raises(CameraService::CaptureError) do
      CameraService.capture_frame(
        agent_dvr_oid: @valid_agent_dvr_oid,
        camera_id: @valid_camera_id
      )
    end

    assert_match /HTTP 500/, error.message
  end

  test "raises CaptureError when response is not JPEG" do
    stub_request(:get, @snapshot_url)
      .to_return(
        status: 200,
        body: "<html>Not an image</html>",
        headers: { 'Content-Type' => 'text/html' }
      )

    error = assert_raises(CameraService::CaptureError) do
      CameraService.capture_frame(
        agent_dvr_oid: @valid_agent_dvr_oid,
        camera_id: @valid_camera_id
      )
    end

    assert_match /expected JPEG/, error.message
  end

  test "raises ConnectionError when Agent DVR connection is refused" do
    stub_request(:get, @snapshot_url)
      .to_raise(Errno::ECONNREFUSED)

    error = assert_raises(CameraService::ConnectionError) do
      CameraService.capture_frame(
        agent_dvr_oid: @valid_agent_dvr_oid,
        camera_id: @valid_camera_id
      )
    end

    assert_match /Agent DVR is not running/, error.message
  end

  test "generates timestamped filename with camera ID" do
    path = CameraService.generate_output_path(123)

    assert path.include?('camera_123_'), "Should include camera ID"
    assert path.match?(/\d{8}_\d{6}\.jpg/), "Should have timestamp format YYYYMMDD_HHMMSS.jpg"
    assert path.start_with?(Rails.root.join('storage', 'events').to_s), "Should be in storage/events"
  end

  test "generates filename without camera ID when nil" do
    path = CameraService.generate_output_path(nil)

    assert path.include?('camera_'), "Should include 'camera_' prefix"
    # When camera_id is nil, filename should be "camera_YYYYMMDD_HHMMSS.jpg" (no number after camera_)
    assert path.match?(/camera_\d{8}_\d{6}\.jpg/), "Should have timestamp directly after 'camera_'"
  end

  test "custom output path is used when provided" do
    custom_path = Rails.root.join('tmp', 'test_image.jpg').to_s

    stub_request(:get, @snapshot_url)
      .to_return(
        status: 200,
        body: @jpeg_data,
        headers: { 'Content-Type' => 'image/jpeg' }
      )

    result = CameraService.capture_frame(
      agent_dvr_oid: @valid_agent_dvr_oid,
      output_path: custom_path
    )

    assert_equal custom_path, result
    assert File.exist?(custom_path), "File should exist at custom path"

    # Cleanup
    File.delete(custom_path) if File.exist?(custom_path)
  end
end
