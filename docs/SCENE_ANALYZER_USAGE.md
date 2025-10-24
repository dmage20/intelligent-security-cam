# SceneAnalyzer Usage Guide

## Overview
SceneAnalyzer integrates Claude Vision API to provide intelligent analysis of camera frames with contextual awareness.

## Setup

### 1. Set API Key (Required)

**Option A: Environment Variable (Recommended for Security)**
```bash
export ANTHROPIC_API_KEY='sk-ant-your-key-here'
```

Add to your shell profile (`~/.zshrc` or `~/.bash_profile`):
```bash
echo 'export ANTHROPIC_API_KEY="sk-ant-your-key-here"' >> ~/.zshrc
source ~/.zshrc
```

**Option B: Database Setting (Fallback)**
```ruby
rails console
Setting.set('anthropic_api_key', 'sk-ant-your-key-here', 'Anthropic Claude API key')
```

**Get an API key**: Visit [console.anthropic.com](https://console.anthropic.com)

### 2. Verify Setup
```ruby
rails console
ENV['ANTHROPIC_API_KEY']  # Should show your key
# or
Setting.anthropic_api_key  # Fallback
```

## Basic Usage

### Analyze a Single Frame

```ruby
# Capture a frame
camera = Camera.first
timestamp = Time.current
image_path = CameraService.capture_frame(
  agent_dvr_oid: camera.agent_dvr_oid,
  camera_id: camera.id
)

# Analyze it with Claude Vision
result = SceneAnalyzer.analyze_comprehensive(image_path, camera, timestamp)

# Result structure:
{
  detected_objects: [
    {
      type: 'person',
      description: 'Person in dark clothing',
      position: { area: 'center', specifics: 'standing near door' },
      confidence: 0.95,
      likely_same_as_tracked: 'person_abc123'  # or nil if new
    }
  ],
  scene_description: 'Person approaching front door in daylight',
  weather: {
    condition: 'clear',  # clear|cloudy|raining|snowing|foggy
    intensity: 'none',   # none|light|moderate|heavy
    changed_from_previous: false
  },
  lighting: 'day',  # day|night|dawn|dusk
  active_object_count: 1,
  change_magnitude: 45,  # 0-100, how much changed from previous scene
  reasoning: 'New person detected approaching entrance. Clear weather...'
}
```

## Contextual Features

SceneAnalyzer automatically includes context to improve analysis:

### 1. Previous Scene State (5 seconds ago)
- Helps detect changes: "package appeared" vs "package still there"
- Weather changes: "started raining"
- Lighting transitions: "dusk turning to night"

### 2. Currently Tracked Objects
- Persistent object tracking: "your package" not just "a package"
- Duration awareness: "been there 3 hours"
- Identity matching: Claude tries to match new detections to existing objects

### 3. Active Routines
- Learned patterns: "person walks dog every morning 7-8am"
- Reduces false positives: "this is normal for this time"
- Only includes high-confidence (>80%) routines

## Advanced Usage

### With Existing Context

```ruby
# Create previous scene state first
previous_state = SceneState.create!(
  camera: camera,
  timestamp: Time.current - 5.seconds,
  overall_description: 'Empty driveway',
  lighting: 'day',
  weather: { condition: 'clear', intensity: 'none' },
  active_object_count: 0
)

# Track an object
tracked_obj = TrackedObject.create!(
  camera: camera,
  object_type: 'package',
  identifier: 'pkg_' + SecureRandom.hex(8),
  status: 'present',
  first_detected_at: Time.current - 2.hours,
  last_detected_at: Time.current - 5.seconds,
  appearance_description: 'Brown cardboard box, medium size'
)

# Now analyze - prompt will include context
result = SceneAnalyzer.analyze_comprehensive(image_path, camera, timestamp)

# Claude will know:
# - Previous scene was empty
# - Package has been there 2 hours
# - Can identify if it's the same package
```

### Create Routine for Time-Aware Analysis

```ruby
routine = Routine.create!(
  camera: camera,
  name: 'Morning mail delivery',
  description: 'USPS truck arrives around 10am weekdays',
  active: true,
  confidence_score: 90,
  time_pattern: {
    hour_range: [9, 11],
    days_of_week: [1, 2, 3, 4, 5]  # Mon-Fri
  },
  frequency: 'weekdays',
  occurrence_count: 20,
  first_seen_at: 30.days.ago,
  last_seen_at: 1.day.ago
)

# Analyze at 10:15am on a weekday
# Claude will see this routine and know it's expected
```

## Integration Example: Full Pipeline

```ruby
camera = Camera.first

# 1. Capture frame
image_path = CameraService.capture_frame(
  agent_dvr_oid: camera.agent_dvr_oid,
  camera_id: camera.id
)

# 2. Analyze with Claude
timestamp = Time.current
analysis = SceneAnalyzer.analyze_comprehensive(image_path, camera, timestamp)

# 3. Create SceneState record
scene_state = SceneState.create!(
  camera: camera,
  timestamp: timestamp,
  overall_description: analysis[:scene_description],
  lighting: analysis[:lighting],
  weather: analysis[:weather],
  active_object_count: analysis[:active_object_count],
  change_magnitude: analysis[:change_magnitude],
  snapshot_image_path: image_path
)

# 4. Create Observation record
observation = Observation.create!(
  camera: camera,
  scene_state: scene_state,
  occurred_at: timestamp,
  description: analysis[:scene_description],
  detected_objects: analysis[:detected_objects],
  analysis: analysis,
  reasoning: analysis[:reasoning],
  image_path: image_path
)

puts "Analysis complete: #{analysis[:scene_description]}"
puts "Detected #{analysis[:detected_objects].length} objects"
```

## Error Handling

```ruby
begin
  result = SceneAnalyzer.analyze_comprehensive(image_path, camera, timestamp)
rescue SceneAnalyzer::AuthenticationError => e
  puts "API key invalid: #{e.message}"
  # Check ENV['ANTHROPIC_API_KEY'] or Setting.anthropic_api_key

rescue SceneAnalyzer::RateLimitError => e
  puts "Rate limit hit: #{e.message}"
  # Wait and retry, or implement exponential backoff

rescue SceneAnalyzer::InvalidImageError => e
  puts "Image problem: #{e.message}"
  # Check image file exists and is valid JPEG

rescue SceneAnalyzer::AnalysisError => e
  puts "Analysis failed: #{e.message}"
  # Network issue, API error, or invalid response
end
```

## Cost Estimation

- Model: `claude-sonnet-4-5` (Claude Sonnet 4.5, latest)
- Input: ~1,500 tokens (image + context)
- Output: ~500 tokens (JSON response)
- Cost: ~$0.015 per analysis (check current Anthropic pricing)

**For continuous monitoring** (every 5 seconds):
- 720 analyses per hour
- ~$10.80/hour per camera
- Consider increasing capture_interval_seconds to reduce costs

## Testing

Run tests without needing real API key:
```bash
rails test test/services/scene_analyzer_test.rb
```

All API calls are mocked with WebMock in tests.

## Next Steps

After implementing SceneAnalyzer, the next priorities are:

1. **ObjectTracker** - Match detected objects to TrackedObjects
2. **ReasoningEngine** - Decide what's notification-worthy
3. **Background Jobs** - Automate frame capture and analysis
4. **Web Interface** - View results in browser

---

**Created**: 2025-10-24
**Priority 2**: ✅ Complete
