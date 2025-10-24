# Camera Monitor - Project Status & Resume Guide

**Last Updated**: October 24, 2025
**Git Commit**: d2d0d1e - "Initial foundation: Camera monitoring system with Claude AI"
**Phase**: Core Services Implementation (2 of 6 complete) 🔄

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
   - ✅ httparty gem (HTTP client for API calls)
   - ✅ base64 gem (image encoding)
   - ✅ dotenv-rails gem (environment variable management)
   - ✅ webmock gem (HTTP request stubbing for tests)
   - ✅ Solid Queue (background jobs - Rails 8 default)
   - ✅ ActionCable (WebSockets - Rails default)

6. **Documentation**
   - ✅ ARCHITECTURE.md - Complete system design
   - ✅ PROJECT_STATUS.md - This file
   - ✅ docs/SETUP.md - Environment setup guide
   - ✅ docs/SCENE_ANALYZER_USAGE.md - Claude Vision API usage
   - ✅ Model comments and inline documentation

7. **Environment Configuration**
   - ✅ .env file created (gitignored)
   - ✅ .env.example template for collaborators
   - ✅ ANTHROPIC_API_KEY configured via ENV variable
   - ✅ dotenv-rails auto-loads .env in development/test

---

## 🔄 NEXT STEPS (Phase 2: Core Services)

When resuming development, start with these tasks in order:

### Priority 1: CameraService (Agent DVR Integration) ✅ COMPLETE
**File created**: `app/services/camera_service.rb`

**Purpose**: Capture single frames from cameras via Agent DVR HTTP API

**Implementation details**:
- [x] Uses Agent DVR as RTSP proxy (solves macOS 26 beta network restrictions)
- [x] HTTP GET from `http://localhost:8090/grab.jpg?oid={camera.agent_dvr_oid}`
- [x] Parameter validation (agent_dvr_oid must be positive integer)
- [x] Error handling: HTTP errors, connection failures, invalid images
- [x] Generates timestamped filenames: `camera_{id}_{YYYYMMDD_HHMMSS}.jpg`
- [x] Saves to `storage/events/` directory
- [x] Comprehensive test suite (13 tests, 36 assertions, all passing)
- [x] Added `agent_dvr_oid` field to Camera model

**Architecture decision**: Agent DVR proxy approach
- macOS 26 beta blocks CLI tools (FFmpeg, OpenCV, GStreamer) from network access
- Agent DVR (signed GUI app) connects to RTSP cameras
- Exposes HTTP API for frame snapshots
- CameraService uses simple HTTParty GET requests

**Example usage**:
```ruby
camera = Camera.first
image_path = CameraService.capture_frame(
  agent_dvr_oid: camera.agent_dvr_oid,
  camera_id: camera.id
)
# => "/path/to/storage/events/camera_1_20241024_153045.jpg"
```

**Completed**: 2025-10-24

### Priority 2: SceneAnalyzer (Claude Vision API) ✅ COMPLETE
**File created**: `app/services/scene_analyzer.rb`

**Purpose**: Send image + contextual prompt to Claude Vision API for intelligent analysis

**Implementation details**:
- [x] Uses Claude Sonnet 4.5 (`claude-sonnet-4-5`) - latest vision model
- [x] Base64 image encoding with JPEG validation (checks magic bytes)
- [x] Contextual prompt building includes:
  - [x] Previous SceneState (from ~5 seconds ago) for change detection
  - [x] Currently tracked objects (status: 'present') for identity matching
  - [x] Active high-confidence routines (>80%) for pattern awareness
  - [x] **Explicit visual lighting analysis** (ignores timestamp to avoid false inference)
- [x] API integration:
  - Model: `claude-sonnet-4-5`
  - Max tokens: 2048
  - Timeout: 30 seconds
  - Headers: x-api-key, anthropic-version, content-type
- [x] Response parsing:
  - Handles markdown code block wrapping
  - Validates required fields
  - Returns structured hash
- [x] Error handling:
  - 401: AuthenticationError
  - 429: RateLimitError (with retry-after)
  - 400: Bad request errors
  - Network timeouts and connection failures
- [x] Security: API key via ENV variable (`.env` file, not database)
- [x] Comprehensive test suite (25 tests, 65 assertions, all passing)
- [x] Successfully tested with real API

**Prompt Engineering Fix (Oct 24)**:
- Added explicit instruction to analyze lighting **visually from image**
- Prevents Claude from inferring "night" based on timestamp when image shows daylight
- Critical for systems where clock time ≠ actual time of day

**Returns**:
```ruby
{
  detected_objects: [{type, description, position, confidence, likely_same_as_tracked}, ...],
  scene_description: "Overall description of what's happening",
  weather: {condition, intensity, changed_from_previous},
  lighting: "day|night|dawn|dusk",  # Determined visually, not from timestamp
  active_object_count: integer,
  change_magnitude: 0-100,
  reasoning: "Claude's thought process"
}
```

**Documentation**: See `docs/SCENE_ANALYZER_USAGE.md` for examples and cost estimation

**Completed**: 2025-10-24

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
[completed] Add required gems (httparty, base64, dotenv-rails, webmock)
[completed] Configure environment variables with .env file
[completed] Build CameraService with Agent DVR integration ✅
[completed] Build SceneAnalyzer with Claude Vision API ✅
[completed] Create comprehensive test suites (38 tests passing)
[completed] Set up API key management (ENV variables)
[completed] Fix lighting detection prompt engineering
[pending] Build ObjectTracker service
[pending] Build ReasoningEngine for contextual analysis
[pending] Build RoutineAnalyzer for pattern discovery
[pending] Build ConversationService for Q&A
[pending] Create background jobs with Solid Queue
[pending] Build web interface with ActionCable
```

---

## 🔑 Configuration Checklist

Before testing services:

- [x] Set environment variable in `.env` file: `ANTHROPIC_API_KEY=sk-ant-...`
- [x] Create storage directory: `mkdir -p storage/events`
- [x] Install Agent DVR from ispyconnect.com
- [x] Configure camera in Agent DVR (get agent_dvr_oid)
- [x] Update Camera record with agent_dvr_oid
- [ ] Add optional settings to database:
  ```ruby
  Setting.set('event_similarity_window', '30', 'Minutes to check for duplicate events')
  Setting.set('routine_min_occurrences', '5', 'Min events before pattern recognized')
  Setting.set('routine_confidence_threshold', '80', 'Min confidence % for routines')
  Setting.set('image_retention_days', '30', 'Days to keep event images')
  ```
- [ ] Consider creating seed data: `rails db:seed`

**Current Setup (Oct 24)**:
- ✅ Camera: "Front Door" (ID: 1, agent_dvr_oid: 3)
- ✅ Agent DVR running on localhost:8090
- ✅ API key configured in .env
- ✅ All tests passing (38 tests, 101 assertions)

---

## 🧪 Testing Strategy

### Unit Testing Services (2 of 6 complete)

Each service is tested independently with mocked external dependencies:

1. **CameraService** ✅:
   - 13 tests, 36 assertions, all passing
   - Uses WebMock to stub Agent DVR HTTP requests
   - Tests: success cases, validation, error handling, file operations

2. **SceneAnalyzer** ✅:
   - 25 tests, 65 assertions, all passing
   - Uses WebMock to stub Anthropic API requests
   - Tests: input validation, API key handling, image encoding, context building, error handling, response parsing
   - No real API calls needed for tests

3. **ObjectTracker**: Create test DetectedObjects, verify matching logic
4. **ReasoningEngine**: Mock Claude response, test decision logic
5. **RoutineAnalyzer**: Create test Observations, verify pattern discovery

**Run all tests**: `rails test` (38 tests, 101 assertions, 0 failures)

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
├── .env                       # ✅ Environment variables (gitignored)
├── .env.example               # ✅ Template for collaborators
├── docs/
│   ├── SETUP.md               # ✅ Environment setup guide
│   └── SCENE_ANALYZER_USAGE.md # ✅ Claude Vision API usage
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
│   ├── services/              # 🔄 2 of 6 complete
│   │   ├── camera_service.rb        # ✅ Complete (Agent DVR)
│   │   ├── scene_analyzer.rb        # ✅ Complete (Claude Vision)
│   │   ├── object_tracker.rb        # 🔄 TO CREATE
│   │   ├── reasoning_engine.rb      # 🔄 TO CREATE
│   │   ├── routine_analyzer.rb      # 🔄 TO CREATE
│   │   └── conversation_service.rb  # 🔄 TO CREATE
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
├── test/
│   ├── services/              # ✅ 2 test files complete
│   │   ├── camera_service_test.rb     # ✅ 13 tests passing
│   │   └── scene_analyzer_test.rb     # ✅ 25 tests passing
│   └── test_helper.rb         # ✅ Configured with WebMock
├── db/
│   ├── migrate/               # ✅ 9 migrations complete
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

**Phase 2 (Services) progress**: 2 of 6 complete (33%)

- [x] CameraService can capture frame from Agent DVR ✅
- [x] SceneAnalyzer successfully calls Claude Vision API ✅
- [ ] ObjectTracker correctly matches objects across frames
- [ ] ReasoningEngine produces contextual notification messages
- [ ] RoutineAnalyzer discovers patterns from test data
- [ ] ConversationService answers natural language questions
- [x] All services have comprehensive error handling ✅
- [ ] Can run full pipeline: capture → analyze → track → reason

**Completed milestones** (Oct 24):
1. ✅ Frame captured to `storage/events/` (via Agent DVR)
2. ✅ Claude Vision API successfully analyzes images
3. ✅ Returns detected_objects, scene_description, weather, lighting
4. ✅ Contextual prompts include previous state and tracked objects
5. ✅ Lighting detection works correctly (visual analysis, not timestamp inference)

**Next milestone**: Implement ObjectTracker to match detected objects to TrackedObjects for persistent tracking

---

## 📝 Notes for Future Sessions

- **API Key**: ✅ Configured in `.env` file, loaded automatically by dotenv-rails
- **Agent DVR**: ✅ Running on localhost:8090, camera oid=3 configured
- **Debugging**: Use `rails console` to test services interactively
- **Image Storage**: ✅ `storage/events/` directory created with write permissions
- **Performance**: Currently testing with 1 camera (Front Door)
- **Model Version**: Using Claude Sonnet 4.5 (`claude-sonnet-4-5`)
- **Lighting Detection**: Prompts explicitly request visual analysis (not timestamp inference)

---

## 🚀 Quick Test Commands

```bash
# Test CameraService
rails runner 'camera = Camera.first; p CameraService.capture_frame(agent_dvr_oid: camera.agent_dvr_oid, camera_id: camera.id)'

# Test SceneAnalyzer
rails runner '
  camera = Camera.first
  image = CameraService.capture_frame(agent_dvr_oid: camera.agent_dvr_oid, camera_id: camera.id)
  result = SceneAnalyzer.analyze_comprehensive(image, camera, Time.current)
  puts result[:scene_description]
'

# Run all tests
rails test
```

---

**Ready to resume? Start with: Build ObjectTracker (Priority 3)**

See ARCHITECTURE.md for detailed system design.
See docs/SCENE_ANALYZER_USAGE.md for Claude Vision API examples.

---

*Checkpoint saved: October 24, 2025*
*2 of 6 core services complete (CameraService, SceneAnalyzer)*
*38 tests passing, 101 assertions, 0 failures*
*Git commit: d2d0d1e*
