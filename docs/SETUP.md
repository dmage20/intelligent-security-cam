# Setup Guide

## Environment Variables

The `ANTHROPIC_API_KEY` is configured via the `.env` file in the project root.

### Current Setup

**Location**: `/Users/danielmage/intelligent-security-cam/.env`

This file is:
- ✅ Already created with placeholder values
- ✅ Automatically loaded by `dotenv-rails` gem
- ✅ Gitignored (won't be committed)

### To Configure Your API Key

1. **Get your Anthropic API key**:
   - Visit [console.anthropic.com](https://console.anthropic.com)
   - Sign up or log in
   - Navigate to API Keys
   - Create a new key

2. **Edit `.env` file**:
   ```bash
   # Open in your editor
   open .env

   # Or use nano
   nano .env
   ```

3. **Replace the placeholder**:
   ```bash
   # Change this:
   ANTHROPIC_API_KEY=your-key-here

   # To your actual key:
   ANTHROPIC_API_KEY=sk-ant-api03-abc123...
   ```

4. **Verify it works**:
   ```bash
   # Restart any running Rails processes, then:
   rails runner 'puts "API Key: #{ENV["ANTHROPIC_API_KEY"][0..15]}..."'

   # Should show: API Key: sk-ant-api03-ab...
   ```

### Alternative: System Environment Variable

For production or if you prefer not to use `.env` files:

**macOS/Linux (permanent)**:
```bash
# Add to ~/.zshrc or ~/.bash_profile
echo 'export ANTHROPIC_API_KEY="sk-ant-your-key"' >> ~/.zshrc
source ~/.zshrc
```

**Current session only**:
```bash
export ANTHROPIC_API_KEY="sk-ant-your-key"
```

### Testing Without Real API Key

All tests use WebMock to stub API calls, so you don't need a real key for testing:

```bash
rails test  # Works without real API key
```

### Security Notes

1. ✅ `.env` is in `.gitignore` - won't be committed to git
2. ✅ `dotenv-rails` only loads in development/test - not production
3. ⚠️ For production, use encrypted credentials or platform ENV vars:
   - Heroku: `heroku config:set ANTHROPIC_API_KEY=sk-ant-...`
   - Render: Set in dashboard under Environment Variables
   - Docker: Use secrets or env files mounted at runtime

### Troubleshooting

**Error: "ANTHROPIC_API_KEY not set"**
```bash
# Check if .env exists
ls -la .env

# Check if it's loaded
rails runner 'puts ENV["ANTHROPIC_API_KEY"]'

# If empty, restart Rails server/console
```

**Error: "Invalid API key"**
- Verify the key starts with `sk-ant-`
- Check for extra spaces or quotes in `.env`
- Ensure the key is active at console.anthropic.com

## Other Configuration

### Agent DVR

If your Agent DVR runs on a different host/port, add to `.env`:

```bash
AGENT_DVR_HOST=192.168.1.100
AGENT_DVR_PORT=8090
```

Then update `app/services/camera_service.rb` to use these ENV vars.

---

**Created**: 2025-10-24
**Next**: See `docs/SCENE_ANALYZER_USAGE.md` for usage examples
