# Camera Monitor - Project Status & Resume Guide

**Last Updated**: October 23, 2025
**Git Commit**: d2d0d1e - "Initial foundation: Camera monitoring system with Claude AI"
**Phase**: Foundation Complete ✅ → Ready for Service Implementation

---

## Current Status Summary

### ✅ COMPLETED (Phase 1: Foundation)

1. **Environment Setup**
   - ✅ Ruby 3.3.6 installed via rbenv
   - ✅ Rails 8.1.0 installed
   - ✅ PostgreSQL 15 installed and configured
   - ✅ PostgreSQL user `dmage20` created with superuser privileges
   - ✅ FFmpeg 5.1.7 installed system-wide

2. **Rails Application**
   - ✅ Generated `camera_monitor` Rails app
   - ✅ Configured for PostgreSQL database
   - ✅ Database created: `camera_monitor_development` and `camera_monitor_test`
   - ✅ All migrations run successfully

3. **Data Models (8 total)**
   - ✅ Camera - RTSP camera configuration
   - ✅ TrackedObject - Persistent object tracking
   - ✅ Observation - Frame analysis records
   - ✅ SceneState - Environmental awareness
   - ✅ Routine - Learned pattern storage
   - ✅ ConversationMemory - Q&A history
   - ✅ Setting - Configuration key-value store
   - ✅ ObservationTrackedObject - Join table

4. **Model Features**
   - ✅ All associations defined (has_many, belongs_to, through)
   - ✅ Validations on all critical fields
   - ✅ Scopes for common queries
   - ✅ Helper methods for business logic
   - ✅ Database indexes for performance

5. **Dependencies**
   - ✅ streamio-ffmpeg gem (FFmpeg wrapper)
   - ✅ httparty gem (HTTP client for Claude API)
   - ✅ base64 gem (image encoding)
   - ✅ Solid Queue (background jobs - Rails 8 default)
   - ✅ ActionCable (WebSockets - Rails default)

6. **Documentation**
   - ✅ ARCHITECTURE.md - Complete system design
   - ✅ PROJECT_STATUS.md - This file
   - ✅ Model comments and inline documentation

---

## 🔄 NEXT STEPS (Phase 2: Core Services)

When resuming development, start with these tasks in order:

### Priority 1: CameraService (FFmpeg Integration)
**File to create**: `app/services/camera_service.rb`

**Purpose**: Capture single frames from RTSP camera streams using FFmpeg

**Implementation checklist**:
- [ ] Create `app/services/` directory
- [ ] Build `CameraService.capture_frame(rtsp_url, output_path)` method
- [ ] Use `FFMPEG::Movie` from streamio-ffmpeg gem
- [ ] Extract single frame at current time
- [ ] Handle errors: connection timeout, invalid URL, stream unavailable
- [ ] Return image file path on success
- [ ] Create storage directory: `storage/events/`
- [ ] Test with sample RTSP URL (or video file for testing)

**Example usage**:
```ruby
camera = Camera.first
image_path = CameraService.capture_frame(camera.rtsp_url)
# => "storage/events/camera_1_20241023_153045.jpg"
```

**Testing without RTSP camera**:
- Use a local video file: `ffmpeg -i test_video.mp4` (convert RTSP URL to file path)
- Or use public RTSP test streams

### Priority 2: SceneAnalyzer (Claude Vision API)
**File to create**: `app/services/scene_analyzer.rb`

**Purpose**: Send image + contextual prompt to Claude Vision API

**Implementation checklist**:
- [ ] Create `SceneAnalyzer.analyze_comprehensive(image_path, camera, timestamp)` method
- [ ] Encode image to base64 using `Base64.strict_encode64`
- [ ] Build comprehensive prompt including:
  - [ ] Previous SceneState (from 5 seconds ago)
  - [ ] Expected TrackedObjects (status: 'present')
  - [ ] Recent Observations (last 10 minutes)
  - [ ] Active Routines matching current time
- [ ] Call Anthropic API using HTTParty:
  ```ruby
  HTTParty.post(
    'https://api.anthropic.com/v1/messages',
    headers: {
      'x-api-key' => Setting.anthropic_api_key,
      'anthropic-version' => '2023-06-01',
      'content-type' => 'application/json'
    },
    body: { model: 'claude-3-5-sonnet-20241022', messages: [...], max_tokens: 2048 }
  )
  ```
- [ ] Parse JSON response
- [ ] Return structured hash: `{detected_objects, scene_description, weather, lighting, reasoning}`
- [ ] Handle API errors (rate limits, auth failures)

**Required**: Set `ANTHROPIC_API_KEY` environment variable

### Priority 3: ObjectTracker
**File to create**: `app/services/object_tracker.rb`

**Purpose**: Match detected objects to existing TrackedObjects

**Implementation checklist**:
- [ ] Create `ObjectTracker.process_frame_detections(detected_objects, camera, timestamp, image_path)`
- [ ] For each detected object:
  - [ ] Find candidate TrackedObjects (same type, status='present', camera_id, recent)
  - [ ] Calculate match scores (position similarity, time proximity)
  - [ ] If clear match (score > 0.70): update existing TrackedObject
  - [ ] If ambiguous (multiple candidates 0.40-0.70): ask Claude to compare images
  - [ ] If no match: create new TrackedObject with unique identifier
  - [ ] Update `last_detected_at`, `position_history`, recalculate `duration_minutes`
- [ ] Mark disappeared objects:
  - [ ] Find TrackedObjects not in current frame (status='present' but not detected)
  - [ ] Call `tracked_object.mark_disappeared!`

**Key challenge**: Matching "is this the SAME package?"
- Use position (nearby last position?)
- Use time (seen recently?)
- Use Claude for visual comparison when uncertain

### Priority 4: ReasoningEngine
**File to create**: `app/services/reasoning_engine.rb`

**Purpose**: Contextual analysis and notification decisions

**Implementation checklist**:
- [ ] Create `ReasoningEngine.analyze_implications(observation, camera)`
- [ ] Gather rich context:
  - [ ] TrackedObjects with durations ("package there 3 hours")
  - [ ] Current weather from SceneState ("it's raining")
  - [ ] Time context (hour, day of week, is_night?)
  - [ ] Recent events (last 2 hours)
  - [ ] Active routines for this time
- [ ] Build reasoning prompt for Claude
- [ ] Ask Claude: "Should we notify? What priority? What message?"
- [ ] Return: `{should_notify, priority, notification_message, reasoning, concerns}`
- [ ] Update Observation with results

**Example output**:
```ruby
{
  should_notify: true,
  priority: 'high',
  notification_message: 'Your package has been outside for 3 hours. Light rain started 45 minutes ago.',
  reasoning: {...},
  concerns: ['package_exposure', 'weather_impact']
}
```

### Priority 5: RoutineAnalyzer
**File to create**: `app/services/routine_analyzer.rb`

**Purpose**: Daily pattern discovery

**Implementation checklist**:
- [ ] Create `RoutineAnalyzer.discover_patterns(camera, days_back = 30)`
- [ ] Fetch Observations from last 30 days
- [ ] Group similar events:
  - [ ] Same detected object types
  - [ ] Similar descriptions
  - [ ] Similar time of day (within 30 min window)
- [ ] Find temporal patterns:
  - [ ] Daily (every day)
  - [ ] Weekdays (Mon-Fri)
  - [ ] Weekly (specific day of week)
  - [ ] Specific days
- [ ] Calculate confidence score (consistency / total days * 100)
- [ ] If confidence > 80% and occurrence_count >= 5:
  - [ ] Create or update Routine record
- [ ] Mark stale routines as inactive (not seen in 7 days)

### Priority 6: ConversationService
**File to create**: `app/services/conversation_service.rb`

**Purpose**: Q&A interface

**Implementation checklist**:
- [ ] Create `ConversationService.ask(question, camera, current_image_path = nil)`
- [ ] Classify question type (object_identification, duration_query, etc.)
- [ ] Gather relevant context based on type:
  - [ ] object_identification: fetch historical person detections + images
  - [ ] duration_query: fetch current TrackedObjects with durations
  - [ ] environmental_query: fetch SceneState weather history
  - [ ] anomaly_detection: fetch today's unusual events
- [ ] Build conversational prompt with context
- [ ] Include relevant historical images (up to 10)
- [ ] Call Claude API
- [ ] Parse response
- [ ] Save to ConversationMemory
- [ ] Return natural language answer

---

## 🔨 PHASE 3: Background Jobs (After Services)

### Jobs to Create

1. **CameraMonitorJob**
   - File: `app/jobs/camera_monitor_job.rb`
   - Frequency: Every 5 seconds per camera
   - Flow:
     1. CameraService.capture_frame
     2. SceneAnalyzer.analyze_comprehensive
     3. ObjectTracker.process_frame_detections
     4. Create SceneState
     5. Create Observation
     6. ReasoningEngine.analyze_implications
     7. If should_notify: broadcast via ActionCable
   - Configure in `config/recurring.yml` (Solid Queue)

2. **RoutineAnalysisJob**
   - File: `app/jobs/routine_analysis_job.rb`
   - Frequency: Daily at 2:00 AM
   - Action: Call RoutineAnalyzer.discover_patterns for each camera

3. **ImageCleanupJob**
   - File: `app/jobs/image_cleanup_job.rb`
   - Frequency: Daily at 3:00 AM
   - Action: Delete images older than `Setting.image_retention_days`

### Solid Queue Configuration
Edit `config/recurring.yml`:
```yaml
production:
  camera_monitor:
    class: CameraMonitorJob
    schedule: every 5 seconds

  routine_analysis:
    class: RoutineAnalysisJob
    schedule: "0 2 * * *"  # Daily 2am

  image_cleanup:
    class: ImageCleanupJob
    schedule: "0 3 * * *"  # Daily 3am
```

---

## 🎨 PHASE 4: Web Interface (After Jobs)

### Controllers to Create

1. **CamerasController**
   - CRUD for Camera records
   - Actions: index, show, new, create, edit, update, destroy
   - Extra: `test_connection` (verify RTSP URL works)

2. **ObservationsController**
   - index (with filters: camera, date range, priority)
   - show (detail view with image, reasoning, related objects)

3. **TrackedObjectsController**
   - index (current objects grouped by camera)
   - show (history of a specific object)

4. **RoutinesController**
   - index (learned patterns)
   - show (routine details)
   - update (toggle auto_suppress)

5. **ConversationsController**
   - index (Q&A history)
   - create (ask new question)

6. **DashboardController**
   - index (overview: cameras, recent events, active objects)

### ActionCable Channels

1. **EventsChannel**
   - Broadcasts new observations with priority > 'none'
   - Client: Browser notifications + UI updates

2. **ObjectsChannel**
   - Broadcasts TrackedObject updates (new, disappeared, duration changes)

### Views & Frontend

- Use Stimulus.js (already included in Rails 8)
- Turbo Frames for dynamic updates
- Stimulus controllers:
  - `camera_controller.js` - live preview, connection testing
  - `notification_controller.js` - browser notifications
  - `conversation_controller.js` - chat interface

---

## 📋 TODO List Snapshot

```
[completed] Install Ruby and Rails 8 environment
[completed] Generate Rails 8 app with PostgreSQL
[completed] Design complete application architecture
[completed] Generate all 7 database models with migrations
[completed] Add model associations and validations
[completed] Install FFmpeg system dependency
[completed] Add required gems (streamio-ffmpeg, HTTP client)
[pending] Build CameraService for RTSP frame capture
[pending] Build SceneAnalyzer with Claude Vision API
[pending] Build ObjectTracker service
[pending] Build ReasoningEngine for contextual analysis
[pending] Build ConversationService for Q&A
[pending] Create background jobs with Solid Queue
[pending] Build web interface with ActionCable
```

---

## 🔑 Configuration Checklist

Before testing services:

- [ ] Set environment variable: `ANTHROPIC_API_KEY=sk-ant-...`
- [ ] Create storage directory: `mkdir -p storage/events`
- [ ] Add initial settings to database:
  ```ruby
  Setting.set('anthropic_api_key', ENV['ANTHROPIC_API_KEY'], 'Claude API key')
  Setting.set('event_similarity_window', '30', 'Minutes to check for duplicate events')
  Setting.set('routine_min_occurrences', '5', 'Min events before pattern recognized')
  Setting.set('routine_confidence_threshold', '80', 'Min confidence % for routines')
  Setting.set('image_retention_days', '30', 'Days to keep event images')
  ```
- [ ] Get test RTSP camera URL or use video file for testing
- [ ] Consider creating seed data: `rails db:seed`

---

## 🧪 Testing Strategy

### Unit Testing Services

Each service should be testable independently:

1. **CameraService**: Test with local video file
2. **SceneAnalyzer**: Mock HTTParty, test prompt building
3. **ObjectTracker**: Create test DetectedObjects, verify matching logic
4. **ReasoningEngine**: Mock Claude response, test decision logic
5. **RoutineAnalyzer**: Create test Observations, verify pattern discovery

### Integration Testing

1. End-to-end flow: Capture → Analyze → Track → Reason → Notify
2. Test with sample images or video clips
3. Verify database records created correctly

### Manual Testing

1. Add a camera via Rails console
2. Run CameraMonitorJob manually
3. Check Observations, TrackedObjects, SceneStates created
4. Ask questions via ConversationService
5. View results in database

---

## 📁 File Structure Reference

```
camera_monitor/
├── ARCHITECTURE.md           # Complete system design
├── PROJECT_STATUS.md          # This file - resume guide
├── app/
│   ├── models/                # ✅ 8 models complete
│   │   ├── camera.rb
│   │   ├── tracked_object.rb
│   │   ├── observation.rb
│   │   ├── scene_state.rb
│   │   ├── routine.rb
│   │   ├── conversation_memory.rb
│   │   ├── setting.rb
│   │   └── observation_tracked_object.rb
│   ├── services/              # 🔄 TO CREATE
│   │   ├── camera_service.rb
│   │   ├── scene_analyzer.rb
│   │   ├── object_tracker.rb
│   │   ├── reasoning_engine.rb
│   │   ├── routine_analyzer.rb
│   │   └── conversation_service.rb
│   ├── jobs/                  # 🔄 TO CREATE
│   │   ├── camera_monitor_job.rb
│   │   ├── routine_analysis_job.rb
│   │   └── image_cleanup_job.rb
│   ├── controllers/           # 🔄 TO CREATE
│   │   ├── cameras_controller.rb
│   │   ├── observations_controller.rb
│   │   ├── tracked_objects_controller.rb
│   │   ├── routines_controller.rb
│   │   ├── conversations_controller.rb
│   │   └── dashboard_controller.rb
│   ├── channels/              # 🔄 TO CREATE
│   │   ├── events_channel.rb
│   │   └── objects_channel.rb
│   └── views/                 # 🔄 TO CREATE
│       ├── cameras/
│       ├── observations/
│       ├── tracked_objects/
│       ├── routines/
│       ├── conversations/
│       └── dashboard/
├── db/
│   ├── migrate/               # ✅ 8 migrations complete
│   └── schema.rb              # ✅ Generated
├── config/
│   ├── database.yml           # ✅ PostgreSQL configured
│   ├── recurring.yml          # 🔄 TO CONFIGURE
│   └── routes.rb              # 🔄 TO ADD ROUTES
├── storage/
│   └── events/                # 🔄 TO CREATE - image storage
└── Gemfile                    # ✅ Updated with gems
```

---

## 💡 Key Design Reminders

When implementing services, remember these architectural decisions:

1. **Object Identity**: TrackedObject represents a specific instance, not just a type
   - Generate unique identifiers: `"package_#{camera.id}_#{Time.now.to_i}"`
   - Match across frames using position + time + visual similarity

2. **Contextual Prompting**: Always include recent history when calling Claude
   - "You saw X 10 minutes ago. Is this the same?"
   - "This usually happens at this time (routine confidence: 95%)"

3. **Notification Suppression**: Multi-layer filtering
   - Check recent duplicates (< 30 min)
   - Check active routines
   - Let Claude decide final priority

4. **Duration Tracking**: Auto-calculate on TrackedObject save
   - Uses `before_save` callback
   - Duration = last_detected_at - first_detected_at

5. **Pattern Learning**: Minimum thresholds before creating Routine
   - At least 5 occurrences
   - At least 80% confidence (consistency)

---

## 🚀 Quick Start Commands (When Resuming)

```bash
# Navigate to project
cd /home/dmage20/camera_monitor

# Activate Ruby environment
export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"

# Verify environment
ruby -v    # Should show 3.3.6
rails -v   # Should show 8.1.0
psql --version  # Should show 15.14

# Check database
rails db:migrate:status

# Start Rails console (for testing)
rails console

# Start development server (when ready)
bin/dev   # Runs Puma + Solid Queue + assets
```

---

## 📞 Common Commands Reference

```bash
# Database
rails db:create          # Create databases
rails db:migrate         # Run migrations
rails db:rollback        # Undo last migration
rails db:seed            # Load seed data
rails db:reset           # Drop + create + migrate + seed

# Console & Testing
rails console            # Open Rails REPL
rails dbconsole          # Open PostgreSQL CLI

# Generation
rails generate service CameraService    # Create service
rails generate job CameraMonitorJob     # Create background job
rails generate controller Cameras       # Create controller

# Background Jobs (Solid Queue)
bin/jobs                 # Start job worker
rails solid_queue:status # Check job status

# Server
bin/dev                  # Development (Puma + jobs + assets)
rails server             # Just Puma (port 3000)
```

---

## ✅ Verification Checklist (Before Resuming)

Run these commands to verify foundation is intact:

```bash
# 1. Ruby version
ruby -v
# Expected: ruby 3.3.6

# 2. Rails version
rails -v
# Expected: Rails 8.1.0

# 3. Database exists
rails runner "puts ActiveRecord::Base.connection.current_database"
# Expected: camera_monitor_development

# 4. All models load
rails runner "puts [Camera, TrackedObject, Observation, SceneState, Routine, ConversationMemory, Setting, ObservationTrackedObject].map(&:name)"
# Expected: All 8 model names

# 5. FFmpeg installed
ffmpeg -version | head -1
# Expected: ffmpeg version 5.1.7

# 6. Gems installed
bundle check
# Expected: The Gemfile's dependencies are satisfied

# 7. Git status
git log --oneline -1
# Expected: d2d0d1e Initial foundation: Camera monitoring system with Claude AI
```

---

## 🎯 Success Criteria for Next Phase

**Phase 2 (Services) will be complete when**:

- [ ] CameraService can capture frame from RTSP URL
- [ ] SceneAnalyzer successfully calls Claude Vision API
- [ ] ObjectTracker correctly matches objects across frames
- [ ] ReasoningEngine produces contextual notification messages
- [ ] RoutineAnalyzer discovers patterns from test data
- [ ] ConversationService answers natural language questions
- [ ] All services have basic error handling
- [ ] Can run full pipeline: capture → analyze → track → reason

**Testing milestone**: Manually run the pipeline with a test camera/video and verify:
1. Frame captured to `storage/events/`
2. SceneState created with weather data
3. TrackedObjects created and tracked across multiple frames
4. Observation created with contextual reasoning
5. Notification message makes sense

---

## 📝 Notes for Future Sessions

- **API Keys**: Remember to set `ANTHROPIC_API_KEY` before testing Claude integration
- **Test Data**: Consider creating sample RTSP stream or using VLC to serve a video file as RTSP
- **Debugging**: Use `rails console` to test services interactively before running jobs
- **Image Storage**: Ensure write permissions on `storage/events/` directory
- **Performance**: Start with 1-2 cameras before scaling to many

---

**Ready to resume? Start with: Build CameraService (Priority 1)**

See ARCHITECTURE.md for detailed system design.

---

*Checkpoint saved: October 23, 2025*
*Foundation complete. Services ready to build.*
*Git commit: d2d0d1e*
