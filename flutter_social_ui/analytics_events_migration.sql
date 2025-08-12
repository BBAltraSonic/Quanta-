-- Analytics Events Table Migration
-- This creates the analytics_events table for tracking user interactions

-- Create the analytics_events table
CREATE TABLE IF NOT EXISTS analytics_events (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  event_type TEXT NOT NULL,
  user_id UUID REFERENCES users(id),
  properties JSONB,
  timestamp TIMESTAMPTZ NOT NULL,
  session_id TEXT,
  platform TEXT DEFAULT 'flutter',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for optimal query performance
CREATE INDEX IF NOT EXISTS idx_analytics_events_user_id ON analytics_events(user_id);
CREATE INDEX IF NOT EXISTS idx_analytics_events_event_type ON analytics_events(event_type);
CREATE INDEX IF NOT EXISTS idx_analytics_events_timestamp ON analytics_events(timestamp);
CREATE INDEX IF NOT EXISTS idx_analytics_events_session_id ON analytics_events(session_id);
CREATE INDEX IF NOT EXISTS idx_analytics_events_created_at ON analytics_events(created_at);

-- Create a compound index for common queries
CREATE INDEX IF NOT EXISTS idx_analytics_events_user_event_time ON analytics_events(user_id, event_type, timestamp);

-- Add RLS (Row Level Security) policies
ALTER TABLE analytics_events ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see their own analytics events
CREATE POLICY "Users can view own analytics events" ON analytics_events
  FOR SELECT USING (auth.uid() = user_id);

-- Policy: Users can insert their own analytics events
CREATE POLICY "Users can insert own analytics events" ON analytics_events
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Policy: Service role can manage all analytics events (for admin/reporting)
CREATE POLICY "Service role can manage all analytics events" ON analytics_events
  FOR ALL USING (auth.role() = 'service_role');

-- Create a view for common analytics queries
CREATE OR REPLACE VIEW analytics_summary AS
SELECT 
  event_type,
  COUNT(*) as event_count,
  COUNT(DISTINCT user_id) as unique_users,
  DATE_TRUNC('hour', timestamp) as hour_bucket
FROM analytics_events
WHERE timestamp >= NOW() - INTERVAL '24 hours'
GROUP BY event_type, DATE_TRUNC('hour', timestamp)
ORDER BY hour_bucket DESC, event_count DESC;

-- Grant necessary permissions
GRANT SELECT ON analytics_summary TO authenticated;
GRANT INSERT ON analytics_events TO authenticated;
GRANT SELECT ON analytics_events TO authenticated;

-- Comment on table and columns for documentation
COMMENT ON TABLE analytics_events IS 'Stores user interaction analytics events from the Flutter app';
COMMENT ON COLUMN analytics_events.event_type IS 'Type of event (e.g., post_view, like_toggle, etc.)';
COMMENT ON COLUMN analytics_events.user_id IS 'ID of the user who triggered the event';
COMMENT ON COLUMN analytics_events.properties IS 'JSON object containing event-specific data';
COMMENT ON COLUMN analytics_events.timestamp IS 'When the event occurred (client-side timestamp)';
COMMENT ON COLUMN analytics_events.session_id IS 'Session identifier for grouping related events';
COMMENT ON COLUMN analytics_events.platform IS 'Platform where the event occurred (flutter, web, etc.)';
COMMENT ON COLUMN analytics_events.created_at IS 'When the record was inserted into the database';
