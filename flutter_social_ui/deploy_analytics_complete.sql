-- Complete Analytics Implementation Deployment Script
-- This script deploys the analytics system as part of the home screen audit completion

-- ==========================================
-- ANALYTICS EVENTS TABLE CREATION
-- ==========================================

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
CREATE INDEX IF NOT EXISTS idx_analytics_events_user_event_time ON analytics_events(user_id, event_type, timestamp);

-- ==========================================
-- ROW LEVEL SECURITY POLICIES
-- ==========================================

-- Enable RLS
ALTER TABLE analytics_events ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view own analytics events" ON analytics_events;
DROP POLICY IF EXISTS "Users can insert own analytics events" ON analytics_events;
DROP POLICY IF EXISTS "Service role can manage all analytics events" ON analytics_events;

-- Create RLS policies
CREATE POLICY "Users can view own analytics events" ON analytics_events
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own analytics events" ON analytics_events
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Service role can manage all analytics events" ON analytics_events
  FOR ALL USING (auth.role() = 'service_role');

-- ==========================================
-- ANALYTICS VIEWS AND FUNCTIONS
-- ==========================================

-- Create analytics summary view
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

-- Create user engagement summary view
CREATE OR REPLACE VIEW user_engagement_summary AS
SELECT 
  user_id,
  COUNT(*) as total_events,
  COUNT(DISTINCT event_type) as unique_event_types,
  COUNT(DISTINCT session_id) as session_count,
  MIN(timestamp) as first_event,
  MAX(timestamp) as last_event,
  DATE_TRUNC('day', timestamp) as activity_date
FROM analytics_events
WHERE timestamp >= NOW() - INTERVAL '7 days'
GROUP BY user_id, DATE_TRUNC('day', timestamp)
ORDER BY activity_date DESC, total_events DESC;

-- Create popular content view
CREATE OR REPLACE VIEW popular_content AS
SELECT 
  (properties->>'post_id')::UUID as post_id,
  event_type,
  COUNT(*) as event_count,
  COUNT(DISTINCT user_id) as unique_users
FROM analytics_events
WHERE event_type IN ('post_view', 'like_toggle', 'comment_add', 'share_attempt', 'bookmark_toggle')
  AND properties->>'post_id' IS NOT NULL
  AND timestamp >= NOW() - INTERVAL '24 hours'
GROUP BY properties->>'post_id', event_type
ORDER BY event_count DESC;

-- ==========================================
-- ANALYTICS HELPER FUNCTIONS
-- ==========================================

-- Function to get user analytics stats
CREATE OR REPLACE FUNCTION get_user_analytics_stats(target_user_id UUID)
RETURNS TABLE (
  total_events BIGINT,
  unique_event_types BIGINT,
  session_count BIGINT,
  first_activity TIMESTAMPTZ,
  last_activity TIMESTAMPTZ,
  most_common_event TEXT
) 
LANGUAGE SQL
SECURITY DEFINER
AS $$
  SELECT 
    COUNT(*) as total_events,
    COUNT(DISTINCT event_type) as unique_event_types,
    COUNT(DISTINCT session_id) as session_count,
    MIN(timestamp) as first_activity,
    MAX(timestamp) as last_activity,
    (
      SELECT event_type
      FROM analytics_events a2
      WHERE a2.user_id = target_user_id
      GROUP BY event_type
      ORDER BY COUNT(*) DESC
      LIMIT 1
    ) as most_common_event
  FROM analytics_events
  WHERE user_id = target_user_id;
$$;

-- Function to get event counts by time period
CREATE OR REPLACE FUNCTION get_event_counts_by_period(
  period_type TEXT DEFAULT 'hour',
  hours_back INTEGER DEFAULT 24
)
RETURNS TABLE (
  time_period TIMESTAMPTZ,
  event_type TEXT,
  event_count BIGINT
)
LANGUAGE SQL
SECURITY DEFINER
AS $$
  SELECT 
    DATE_TRUNC(period_type, timestamp) as time_period,
    event_type,
    COUNT(*) as event_count
  FROM analytics_events
  WHERE timestamp >= NOW() - (hours_back || ' hours')::INTERVAL
  GROUP BY DATE_TRUNC(period_type, timestamp), event_type
  ORDER BY time_period DESC, event_count DESC;
$$;

-- ==========================================
-- PERMISSIONS AND GRANTS
-- ==========================================

-- Grant necessary permissions
GRANT SELECT ON analytics_summary TO authenticated;
GRANT SELECT ON user_engagement_summary TO authenticated;
GRANT SELECT ON popular_content TO authenticated;
GRANT INSERT ON analytics_events TO authenticated;
GRANT SELECT ON analytics_events TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_analytics_stats(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_event_counts_by_period(TEXT, INTEGER) TO authenticated;

-- ==========================================
-- TABLE COMMENTS FOR DOCUMENTATION
-- ==========================================

COMMENT ON TABLE analytics_events IS 'Stores user interaction analytics events from the Flutter app';
COMMENT ON COLUMN analytics_events.event_type IS 'Type of event (e.g., post_view, like_toggle, etc.)';
COMMENT ON COLUMN analytics_events.user_id IS 'ID of the user who triggered the event';
COMMENT ON COLUMN analytics_events.properties IS 'JSON object containing event-specific data';
COMMENT ON COLUMN analytics_events.timestamp IS 'When the event occurred (client-side timestamp)';
COMMENT ON COLUMN analytics_events.session_id IS 'Session identifier for grouping related events';
COMMENT ON COLUMN analytics_events.platform IS 'Platform where the event occurred (flutter, web, etc.)';
COMMENT ON COLUMN analytics_events.created_at IS 'When the record was inserted into the database';

COMMENT ON VIEW analytics_summary IS 'Hourly summary of analytics events over the last 24 hours';
COMMENT ON VIEW user_engagement_summary IS 'Daily user engagement metrics over the last 7 days';
COMMENT ON VIEW popular_content IS 'Popular content based on user interactions in the last 24 hours';

-- ==========================================
-- DEPLOYMENT VERIFICATION
-- ==========================================

-- Verify the table was created successfully
DO $$
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'analytics_events') THEN
        RAISE NOTICE 'SUCCESS: analytics_events table created successfully';
    ELSE
        RAISE EXCEPTION 'ERROR: analytics_events table was not created';
    END IF;
END $$;

-- Verify indexes were created
DO $$
BEGIN
    IF EXISTS (SELECT FROM pg_indexes WHERE tablename = 'analytics_events' AND indexname = 'idx_analytics_events_user_id') THEN
        RAISE NOTICE 'SUCCESS: Analytics indexes created successfully';
    ELSE
        RAISE EXCEPTION 'ERROR: Analytics indexes were not created';
    END IF;
END $$;

-- Verify RLS is enabled
DO $$
BEGIN
    IF EXISTS (SELECT FROM pg_tables WHERE tablename = 'analytics_events' AND rowsecurity = true) THEN
        RAISE NOTICE 'SUCCESS: Row Level Security enabled on analytics_events';
    ELSE
        RAISE EXCEPTION 'ERROR: Row Level Security not enabled on analytics_events';
    END IF;
END $$;

RAISE NOTICE 'Analytics implementation deployment completed successfully!';
RAISE NOTICE 'All analytics events from the Flutter app will now be tracked in the analytics_events table.';
RAISE NOTICE 'Use the analytics_summary, user_engagement_summary, and popular_content views for reporting.';
