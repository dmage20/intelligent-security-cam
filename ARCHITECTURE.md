# Camera Monitor - Architecture Documentation

## Overview
An intelligent camera monitoring system using Rails 8 and Claude AI that learns routines, tracks persistent objects, provides conversational Q&A, and sends contextual notifications.

## System Architecture

### Technology Stack
- **Backend**: Rails 8.1.0, Ruby 3.3.6
- **Database**: PostgreSQL 15
- **Background Jobs**: Solid Queue (Rails 8 default)
- **Real-time**: ActionCable (WebSockets)
- **Frame Capture**: FFmpeg 5.1.7 + streamio-ffmpeg gem
- **AI Analysis**: Anthropic Claude API (Vision + Reasoning)
- **HTTP Client**: HTTParty
- **Image Storage**: Local filesystem (future: cloud storage)

## Data Models

### 1. Camera
Represents a physical camera being monitored.
- **Fields**: name, rtsp_url, active, description, capture_interval_seconds (default: 5)
- **Associations**: has_many tracked_objects, observations, scene_states, routines, conversation_memories
- **Validations**: RTSP URL format, capture interval 1-3600 seconds

### 2. TrackedObject
Persistent tracking of specific objects across frames (THAT package, not just "a package").
- **Fields**:
  - camera_id, object_type, identifier (unique)
  - first_detected_at, last_detected_at, disappeared_at
  - status (present/disappeared/uncertain)
  - duration_minutes (auto-calculated)
  - position_history (jsonb array)
  - appearance_description (text)
  - visual_fingerprint (jsonb for matching)
  - confidence_score, metadata (jsonb)
- **Purpose**: Track "your package has been there 3 hours" vs just detecting "a package"
- **Methods**:
  - `calculate_duration` - auto-updates on save
  - `mark_disappeared!` - when object leaves frame
  - `duration_human` - "3h 24m" formatting

### 3. Observation (formerly Event)
A single analysis of a camera frame at a point in time.
- **Fields**:
  - camera_id, scene_state_id, event_type
  - description, image_path
  - detected_objects (jsonb array)
  - analysis (jsonb - full Claude response)
  - reasoning (jsonb - Claude's thought process)
  - occurred_at
  - is_routine (boolean)
  - routine_id (optional FK)
  - notification_sent, suppression_reason
  - notification_priority (none/low/medium/high/urgent)
  - notification_message (contextual human message)
  - similarity_score
- **Associations**: belongs_to camera, scene_state, routine; has_many tracked_objects
- **Purpose**: Records what happened + why it matters + should we notify

### 4. SceneState
Environmental awareness at a point in time.
- **Fields**:
  - camera_id, timestamp
  - weather (jsonb: condition, intensity, started_at)
  - lighting (day/night/dawn/dusk)
  - temperature_indication
  - overall_description
  - active_object_count
  - change_magnitude (0-100)
  - snapshot_image_path
- **Purpose**: "It's raining" + "Dog is outside" = concern

### 5. Routine
Learned patterns from recurring events.
- **Fields**:
  - camera_id, name, description
  - event_signature (jsonb: objects, scene_description)
  - time_pattern (jsonb: days_of_week, hour_range)
  - frequency (daily/weekdays/weekly/specific_days)
  - confidence_score (0-100)
  - occurrence_count, first_seen_at, last_seen_at
  - active (boolean)
  - auto_suppress (suppress notifications for this routine)
- **Purpose**: Learn "person walks dog 7-7:30am weekdays" → don't spam notifications
- **Methods**:
  - `matches_time?(timestamp)` - check if routine applies now
  - `increment_occurrence!` - update when seen again

### 6. ConversationMemory
Q&A history with Claude about cameras.
- **Fields**:
  - camera_id, question, question_type
  - answer, reasoning (jsonb)
  - context_used (jsonb - what data was analyzed)
  - relevant_observation_ids, relevant_tracked_object_ids (arrays)
  - images_analyzed (array)
  - asked_at, confidence_in_answer (0-100)
- **Question Types**:
  - object_identification: "Have you seen that person before?"
  - duration_query: "How long has that package been there?"
  - environmental_query: "Is it raining?"
  - anomaly_detection: "Anything unusual today?"
  - routine_query: "Does this happen a lot?"
  - historical_query: "Have you ever seen..."
- **Purpose**: Conversational interface to camera intelligence

### 7. Setting
Key-value configuration store.
- **Fields**: key (unique), value, description
- **Class Methods**:
  - `Setting.get(key, default)` / `Setting.set(key, value, description)`
  - `anthropic_api_key` - Claude API key
  - `event_similarity_window_minutes` - how long to check for duplicates (default: 30)
  - `routine_min_occurrences` - min events before pattern recognized (default: 5)
  - `routine_confidence_threshold` - min confidence % (default: 80)
  - `image_retention_days` - how long to keep images (default: 30)

### 8. ObservationTrackedObject (Join Table)
Links observations to the specific objects detected in that frame.
- **Fields**: observation_id, tracked_object_id, state_in_frame, position (jsonb), confidence
- **State in Frame**: appeared, present, disappeared, moved

## Planned Services (Not Yet Built)

### CameraService
Captures frames from RTSP streams using FFmpeg.
- Input: Camera record
- Output: Image file path
- Error handling: connection failures, stream unavailable

### SceneAnalyzer
Sends frames to Claude Vision API with contextual prompts.
- Input: Image path, camera, timestamp
- Context: Recent events, active routines, tracked objects
- Output: Detected objects, weather, scene description, reasoning
- Prompt includes: "You saw X 10 minutes ago. Is this the same?"

### ObjectTracker
Matches detected objects to existing TrackedObjects.
- Input: Detected objects from SceneAnalyzer
- Logic:
  1. Calculate match scores (position, time, visual similarity)
  2. If ambiguous, ask Claude to decide
  3. Update existing or create new TrackedObject
  4. Mark disappeared objects
- Output: Updated TrackedObject records

### ReasoningEngine
Contextual analysis and notification decisions.
- Input: Observation + full context
- Context:
  - Object durations ("package there 3 hours")
  - Weather ("it's raining")
  - Time of day ("unusual for 11pm")
  - Active routines ("this usually happens")
- Output:
  - should_notify, priority level
  - Contextual message: "Your package has been in the rain for 2 hours"
  - Reasoning (for debugging/transparency)

### RoutineAnalyzer
Daily pattern discovery.
- Input: Camera's historical observations (last 30 days)
- Logic:
  1. Group similar events
  2. Find temporal patterns
  3. Calculate confidence scores
  4. Create/update Routine records
- Output: Routine records with confidence scores

### ConversationService
Q&A interface.
- Input: Natural language question, camera, optional current image
- Logic:
  1. Classify question type
  2. Gather relevant context (observations, tracked objects, routines)
  3. Select relevant historical images
  4. Build comprehensive prompt for Claude
  5. Store conversation in ConversationMemory
- Output: Natural language answer with reasoning

## Processing Pipeline (Per Frame)

```
Every 5 seconds per active camera:

1. CameraService.capture_frame(camera.rtsp_url)
   → /storage/events/camera_1_20241023_153045.jpg

2. SceneAnalyzer.analyze_comprehensive(image, camera, timestamp)
   Prompt includes:
   - Previous scene state (5 seconds ago)
   - Expected objects (tracked objects still "present")
   - Recent observations (last 10 minutes)
   - Active routines for this time
   → {detected_objects, weather, scene_description, reasoning}

3. ObjectTracker.process_frame_detections(detected_objects, camera, timestamp)
   For each object:
   - Match to existing TrackedObject (position + time + visual)
   - If ambiguous → ask Claude with comparison images
   - Update last_detected_at, position_history
   - Calculate duration
   Mark disappeared objects not seen in frame

4. SceneState.create!(camera, timestamp, weather, lighting, ...)

5. Observation.create!(camera, detected_objects, scene_state, ...)

6. ReasoningEngine.analyze_implications(observation, camera)
   Context:
   - TrackedObjects with durations
   - Weather conditions
   - Time context
   - Active routines
   → {should_notify, priority, contextual_message, reasoning}

7. observation.update!(notification_*, reasoning)

8. IF should_notify:
   - EventsChannel.broadcast(observation)
   - Browser shows: "Package outside 3h in rain"

9. (Daily 2am) RoutineAnalyzer.discover_patterns(camera)
   → Creates/updates Routine records
```

## Key Design Decisions

### 1. Object Persistence vs Event Detection
**Problem**: Traditional systems detect "a package" every frame → spam
**Solution**: TrackedObject maintains identity across frames
- Same package tracked from appearance → disappearance
- Duration calculated automatically
- Enables "package there 3 hours" messaging

### 2. Contextual Prompting
**Problem**: Claude doesn't know what's "normal" for this camera
**Solution**: Include recent history + routines in every prompt
- "You saw person walking dog 10 min ago. Same person?"
- "This happens every weekday 7am (95% confidence)"
- Reduces false positives dramatically

### 3. Routine Learning
**Problem**: Daily events shouldn't trigger notifications
**Solution**: RoutineAnalyzer discovers patterns automatically
- After 5+ occurrences at similar time → creates Routine
- Can auto-suppress notifications
- User can override (always notify / never notify)

### 4. Smart Notification Suppression
**Problem**: Don't spam user with repetitive alerts
**Solution**: Multi-layer suppression
1. Recent duplicate check (same event <30 min ago)
2. Routine check (is this expected?)
3. Reasoning check (does this actually matter?)

### 5. Conversational Memory
**Problem**: Users want to ask questions naturally
**Solution**: ConversationService with question classification
- Determines what context is needed
- Gathers relevant data automatically
- Stores Q&A for learning user interests

## Database Indexes

Performance-critical indexes:
- `cameras(active)` - find active cameras quickly
- `tracked_objects(camera_id, status, object_type)` - query present objects
- `tracked_objects(identifier)` - unique constraint
- `tracked_objects(last_detected_at)` - find stale objects
- `observations(camera_id, occurred_at)` - time-series queries
- `observations(is_routine)` - filter non-routine events
- `scene_states(camera_id, timestamp)` - recent weather/conditions
- `routines(camera_id, active)` - active patterns
- `settings(key)` - unique configuration lookup

## Next Implementation Steps

1. ✅ Foundation complete
2. 🔄 Build CameraService (FFmpeg integration)
3. ⏳ Build SceneAnalyzer (Claude Vision API)
4. ⏳ Build ObjectTracker (matching logic)
5. ⏳ Build ReasoningEngine (contextual decisions)
6. ⏳ Build RoutineAnalyzer (pattern discovery)
7. ⏳ Build ConversationService (Q&A)
8. ⏳ Background jobs (Solid Queue recurring)
9. ⏳ Web interface (controllers + views + Stimulus)
10. ⏳ ActionCable channels (real-time updates)

## Configuration Requirements

### Environment Variables
```bash
ANTHROPIC_API_KEY=sk-ant-...  # Required for Claude API
```

### Database Setup
```bash
rails db:create
rails db:migrate
```

### FFmpeg
Must be installed system-wide:
```bash
sudo apt install ffmpeg  # ✅ Already installed (v5.1.7)
```

### Storage Directory
Images stored in: `storage/events/`
- Automatically cleaned after `image_retention_days` (default: 30)

## Current Status

**Phase**: Foundation Complete ✅

**Completed**:
- ✅ Rails 8.1.0 app with PostgreSQL 15
- ✅ All 7 data models + join table
- ✅ Associations, validations, scopes, helper methods
- ✅ Database migrations with indexes
- ✅ FFmpeg 5.1.7 installed
- ✅ Required gems: streamio-ffmpeg, httparty, base64

**Ready for**:
- Building core services (CameraService, SceneAnalyzer, etc.)
- Background job setup
- Web interface development

**TODO from previous session**:
This is where we saved our progress. The foundation is solid and ready for service implementation.

---

*Generated: October 23, 2025*
*Rails 8.1.0 | Ruby 3.3.6 | PostgreSQL 15*
