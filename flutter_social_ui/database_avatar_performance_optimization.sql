-- Avatar Performance Optimization Migration
-- This file contains database optimizations for avatar-centric operations

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS btree_gin;

-- ========== OPTIMIZED INDEXES ==========

-- Avatar indexes for efficient queries
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_avatars_owner_user_id 
ON avatars(owner_user_id);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_avatars_created_at 
ON avatars(created_at DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_avatars_name_trgm 
ON avatars USING gin(name gin_trgm_ops);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_avatars_bio_trgm 
ON avatars USING gin(bio gin_trgm_ops);

-- Posts indexes for avatar queries
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_posts_avatar_id_created_at 
ON posts(avatar_id, created_at DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_posts_avatar_id_likes 
ON posts(avatar_id, likes_count DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_posts_avatar_id_active 
ON posts(avatar_id, is_active) WHERE is_active = true;

-- Follows indexes for avatar stats
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_follows_avatar_id 
ON follows(avatar_id);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_follows_user_avatar 
ON follows(user_id, avatar_id);

-- Composite indexes for performance
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_posts_trending 
ON posts(created_at DESC, likes_count DESC, comments_count DESC) 
WHERE created_at >= NOW() - INTERVAL '30 days' AND is_active = true;

-- Users active avatar index
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_users_active_avatar_id 
ON users(active_avatar_id) WHERE active_avatar_id IS NOT NULL;

-- ========== OPTIMIZED RPC FUNCTIONS ==========

-- Function to get avatar profile with stats in a single query
CREATE OR REPLACE FUNCTION get_avatar_profile_optimized(avatar_id_param UUID)
RETURNS JSON AS $$
DECLARE
  result JSON;
BEGIN
  SELECT json_build_object(
    'avatar', row_to_json(a.*),
    'stats', json_build_object(
      'followers_count', COALESCE(f.followers_count, 0),
      'posts_count', COALESCE(p.posts_count, 0),
      'total_likes', COALESCE(p.total_likes, 0),
      'engagement_rate', COALESCE(p.engagement_rate, 0.0)
    )
  ) INTO result
  FROM avatars a
  LEFT JOIN (
    SELECT 
      avatar_id,
      COUNT(*) as followers_count
    FROM follows 
    WHERE avatar_id = avatar_id_param
    GROUP BY avatar_id
  ) f ON a.id = f.avatar_id
  LEFT JOIN (
    SELECT 
      avatar_id,
      COUNT(*) as posts_count,
      SUM(likes_count) as total_likes,
      AVG(CASE 
        WHEN views_count > 0 THEN (likes_count + comments_count)::float / views_count 
        ELSE 0 
      END) as engagement_rate
    FROM posts 
    WHERE avatar_id = avatar_id_param AND is_active = true
    GROUP BY avatar_id
  ) p ON a.id = p.avatar_id
  WHERE a.id = avatar_id_param;
  
  RETURN result;
END;
$$ LANGUAGE plpgsql;

-- Function to get multiple avatars with stats
CREATE OR REPLACE FUNCTION get_multiple_avatars_optimized(avatar_ids_param UUID[])
RETURNS JSON AS $$
BEGIN
  RETURN (
    SELECT json_agg(
      json_build_object(
        'avatar', row_to_json(a.*),
        'stats', json_build_object(
          'followers_count', COALESCE(f.followers_count, 0),
          'posts_count', COALESCE(p.posts_count, 0),
          'total_likes', COALESCE(p.total_likes, 0)
        )
      )
    )
    FROM avatars a
    LEFT JOIN (
      SELECT 
        avatar_id,
        COUNT(*) as followers_count
      FROM follows 
      WHERE avatar_id = ANY(avatar_ids_param)
      GROUP BY avatar_id
    ) f ON a.id = f.avatar_id
    LEFT JOIN (
      SELECT 
        avatar_id,
        COUNT(*) as posts_count,
        SUM(likes_count) as total_likes
      FROM posts 
      WHERE avatar_id = ANY(avatar_ids_param) AND is_active = true
      GROUP BY avatar_id
    ) p ON a.id = p.avatar_id
    WHERE a.id = ANY(avatar_ids_param)
  );
END;
$$ LANGUAGE plpgsql;

-- Function to get user avatars with stats
CREATE OR REPLACE FUNCTION get_user_avatars_optimized(user_id_param UUID)
RETURNS JSON AS $$
BEGIN
  RETURN (
    SELECT json_agg(
      json_build_object(
        'avatar', row_to_json(a.*),
        'stats', json_build_object(
          'followers_count', COALESCE(f.followers_count, 0),
          'posts_count', COALESCE(p.posts_count, 0),
          'total_likes', COALESCE(p.total_likes, 0)
        )
      )
    )
    FROM avatars a
    LEFT JOIN (
      SELECT 
        avatar_id,
        COUNT(*) as followers_count
      FROM follows 
      GROUP BY avatar_id
    ) f ON a.id = f.avatar_id
    LEFT JOIN (
      SELECT 
        avatar_id,
        COUNT(*) as posts_count,
        SUM(likes_count) as total_likes
      FROM posts 
      WHERE is_active = true
      GROUP BY avatar_id
    ) p ON a.id = p.avatar_id
    WHERE a.owner_user_id = user_id_param
    ORDER BY a.created_at DESC
  );
END;
$$ LANGUAGE plpgsql;

-- Function to get avatar posts with pagination
CREATE OR REPLACE FUNCTION get_avatar_posts_optimized(
  avatar_id_param UUID,
  offset_param INT DEFAULT 0,
  limit_param INT DEFAULT 20
)
RETURNS JSON AS $$
BEGIN
  RETURN json_build_object(
    'posts', (
      SELECT json_agg(row_to_json(p.*))
      FROM posts p
      WHERE p.avatar_id = avatar_id_param AND p.is_active = true
      ORDER BY p.created_at DESC
      LIMIT limit_param OFFSET offset_param
    ),
    'total_count', (
      SELECT COUNT(*)
      FROM posts
      WHERE avatar_id = avatar_id_param AND is_active = true
    ),
    'has_more', (
      SELECT COUNT(*) > (offset_param + limit_param)
      FROM posts
      WHERE avatar_id = avatar_id_param AND is_active = true
    )
  );
END;
$$ LANGUAGE plpgsql;

-- Function to get trending avatars
CREATE OR REPLACE FUNCTION get_trending_avatars_optimized(
  limit_param INT DEFAULT 10,
  timeframe_param TEXT DEFAULT '7d'
)
RETURNS JSON AS $$
DECLARE
  time_filter TIMESTAMP;
BEGIN
  -- Calculate time filter based on timeframe
  CASE timeframe_param
    WHEN '1d' THEN time_filter := NOW() - INTERVAL '1 day';
    WHEN '7d' THEN time_filter := NOW() - INTERVAL '7 days';
    WHEN '30d' THEN time_filter := NOW() - INTERVAL '30 days';
    ELSE time_filter := NOW() - INTERVAL '7 days';
  END CASE;

  RETURN (
    SELECT json_agg(
      json_build_object(
        'avatar', row_to_json(a.*),
        'trending_score', t.trending_score,
        'stats', json_build_object(
          'followers_count', COALESCE(f.followers_count, 0),
          'recent_posts', COALESCE(t.recent_posts, 0),
          'recent_engagement', COALESCE(t.recent_engagement, 0)
        )
      )
    )
    FROM avatars a
    INNER JOIN (
      SELECT 
        avatar_id,
        COUNT(*) as recent_posts,
        SUM(likes_count + comments_count + shares_count) as recent_engagement,
        (COUNT(*) * 0.3 + SUM(likes_count + comments_count + shares_count) * 0.7) as trending_score
      FROM posts
      WHERE created_at >= time_filter AND is_active = true
      GROUP BY avatar_id
      HAVING COUNT(*) > 0
      ORDER BY trending_score DESC
      LIMIT limit_param
    ) t ON a.id = t.avatar_id
    LEFT JOIN (
      SELECT 
        avatar_id,
        COUNT(*) as followers_count
      FROM follows 
      GROUP BY avatar_id
    ) f ON a.id = f.avatar_id
    ORDER BY t.trending_score DESC
  );
END;
$$ LANGUAGE plpgsql;

-- Function to search avatars with full-text search
CREATE OR REPLACE FUNCTION search_avatars_optimized(
  search_query TEXT,
  offset_param INT DEFAULT 0,
  limit_param INT DEFAULT 20
)
RETURNS JSON AS $$
BEGIN
  RETURN (
    SELECT json_agg(
      json_build_object(
        'avatar', row_to_json(a.*),
        'similarity', similarity(a.name, search_query),
        'stats', json_build_object(
          'followers_count', COALESCE(f.followers_count, 0),
          'posts_count', COALESCE(p.posts_count, 0)
        )
      )
    )
    FROM avatars a
    LEFT JOIN (
      SELECT 
        avatar_id,
        COUNT(*) as followers_count
      FROM follows 
      GROUP BY avatar_id
    ) f ON a.id = f.avatar_id
    LEFT JOIN (
      SELECT 
        avatar_id,
        COUNT(*) as posts_count
      FROM posts 
      WHERE is_active = true
      GROUP BY avatar_id
    ) p ON a.id = p.avatar_id
    WHERE 
      a.name ILIKE '%' || search_query || '%' OR
      a.bio ILIKE '%' || search_query || '%' OR
      similarity(a.name, search_query) > 0.3
    ORDER BY 
      similarity(a.name, search_query) DESC,
      COALESCE(f.followers_count, 0) DESC
    LIMIT limit_param OFFSET offset_param
  );
END;
$$ LANGUAGE plpgsql;

-- Function to get avatar engagement metrics
CREATE OR REPLACE FUNCTION get_avatar_engagement_metrics(
  avatar_id_param UUID,
  timeframe_param TEXT DEFAULT '30d'
)
RETURNS JSON AS $$
DECLARE
  time_filter TIMESTAMP;
BEGIN
  -- Calculate time filter based on timeframe
  CASE timeframe_param
    WHEN '7d' THEN time_filter := NOW() - INTERVAL '7 days';
    WHEN '30d' THEN time_filter := NOW() - INTERVAL '30 days';
    WHEN '90d' THEN time_filter := NOW() - INTERVAL '90 days';
    ELSE time_filter := NOW() - INTERVAL '30 days';
  END CASE;

  RETURN (
    SELECT json_build_object(
      'total_views', COALESCE(SUM(views_count), 0),
      'total_likes', COALESCE(SUM(likes_count), 0),
      'total_comments', COALESCE(SUM(comments_count), 0),
      'total_shares', COALESCE(SUM(shares_count), 0),
      'avg_engagement_per_post', COALESCE(AVG(likes_count + comments_count + shares_count), 0),
      'posts_count', COUNT(*),
      'engagement_rate', CASE 
        WHEN SUM(views_count) > 0 THEN 
          (SUM(likes_count + comments_count + shares_count)::float / SUM(views_count)) * 100
        ELSE 0 
      END
    )
    FROM posts
    WHERE avatar_id = avatar_id_param 
      AND created_at >= time_filter 
      AND is_active = true
  );
END;
$$ LANGUAGE plpgsql;

-- Function to batch update avatar stats
CREATE OR REPLACE FUNCTION batch_update_avatar_stats(updates_param JSON)
RETURNS VOID AS $$
DECLARE
  update_record JSON;
BEGIN
  FOR update_record IN SELECT * FROM json_array_elements(updates_param)
  LOOP
    UPDATE avatars 
    SET 
      followers_count = COALESCE((update_record->>'followers_count')::INT, followers_count),
      likes_count = COALESCE((update_record->>'likes_count')::INT, likes_count),
      engagement_rate = COALESCE((update_record->>'engagement_rate')::FLOAT, engagement_rate),
      updated_at = NOW()
    WHERE id = (update_record->>'avatar_id')::UUID;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Function to get database performance metrics
CREATE OR REPLACE FUNCTION get_avatar_db_performance_metrics()
RETURNS JSON AS $$
BEGIN
  RETURN json_build_object(
    'total_avatars', (SELECT COUNT(*) FROM avatars),
    'total_posts', (SELECT COUNT(*) FROM posts WHERE is_active = true),
    'total_follows', (SELECT COUNT(*) FROM follows),
    'avg_posts_per_avatar', (
      SELECT AVG(post_count) FROM (
        SELECT COUNT(*) as post_count 
        FROM posts 
        WHERE is_active = true 
        GROUP BY avatar_id
      ) subq
    ),
    'avg_followers_per_avatar', (
      SELECT AVG(follower_count) FROM (
        SELECT COUNT(*) as follower_count 
        FROM follows 
        GROUP BY avatar_id
      ) subq
    ),
    'index_usage', (
      SELECT json_object_agg(indexname, idx_scan)
      FROM pg_stat_user_indexes 
      WHERE schemaname = 'public' 
        AND indexname LIKE 'idx_avatars%' 
        OR indexname LIKE 'idx_posts%' 
        OR indexname LIKE 'idx_follows%'
    )
  );
END;
$$ LANGUAGE plpgsql;

-- Function to analyze query performance
CREATE OR REPLACE FUNCTION analyze_avatar_query_performance(operation_param TEXT)
RETURNS JSON AS $$
BEGIN
  -- This would contain actual query analysis logic
  -- For now, return placeholder data
  RETURN json_build_object(
    'operation', operation_param,
    'avg_execution_time_ms', 0,
    'index_usage', 'optimal',
    'recommendations', ARRAY[]::TEXT[]
  );
END;
$$ LANGUAGE plpgsql;

-- ========== MATERIALIZED VIEWS FOR PERFORMANCE ==========

-- Materialized view for avatar stats (refreshed periodically)
CREATE MATERIALIZED VIEW IF NOT EXISTS avatar_stats_mv AS
SELECT 
  a.id as avatar_id,
  a.name,
  a.owner_user_id,
  COALESCE(f.followers_count, 0) as followers_count,
  COALESCE(p.posts_count, 0) as posts_count,
  COALESCE(p.total_likes, 0) as total_likes,
  COALESCE(p.avg_engagement, 0) as avg_engagement,
  a.updated_at
FROM avatars a
LEFT JOIN (
  SELECT 
    avatar_id,
    COUNT(*) as followers_count
  FROM follows 
  GROUP BY avatar_id
) f ON a.id = f.avatar_id
LEFT JOIN (
  SELECT 
    avatar_id,
    COUNT(*) as posts_count,
    SUM(likes_count) as total_likes,
    AVG(likes_count + comments_count + shares_count) as avg_engagement
  FROM posts 
  WHERE is_active = true
  GROUP BY avatar_id
) p ON a.id = p.avatar_id;

-- Create unique index on materialized view
CREATE UNIQUE INDEX IF NOT EXISTS idx_avatar_stats_mv_avatar_id 
ON avatar_stats_mv(avatar_id);

-- Function to refresh avatar stats materialized view
CREATE OR REPLACE FUNCTION refresh_avatar_stats_mv()
RETURNS VOID AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY avatar_stats_mv;
END;
$$ LANGUAGE plpgsql;

-- ========== PERFORMANCE MONITORING ==========

-- Create table for query performance tracking
CREATE TABLE IF NOT EXISTS avatar_query_performance (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  operation_name TEXT NOT NULL,
  execution_time_ms INTEGER NOT NULL,
  parameters JSON,
  executed_at TIMESTAMP DEFAULT NOW()
);

-- Index for performance tracking
CREATE INDEX IF NOT EXISTS idx_avatar_query_performance_operation 
ON avatar_query_performance(operation_name, executed_at DESC);

-- Function to log query performance
CREATE OR REPLACE FUNCTION log_avatar_query_performance(
  operation_name_param TEXT,
  execution_time_ms_param INTEGER,
  parameters_param JSON DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
  INSERT INTO avatar_query_performance (operation_name, execution_time_ms, parameters)
  VALUES (operation_name_param, execution_time_ms_param, parameters_param);
  
  -- Keep only last 10000 records to prevent table bloat
  DELETE FROM avatar_query_performance 
  WHERE id IN (
    SELECT id FROM avatar_query_performance 
    ORDER BY executed_at DESC 
    OFFSET 10000
  );
END;
$$ LANGUAGE plpgsql;

-- ========== CLEANUP AND MAINTENANCE ==========

-- Function to cleanup old performance data
CREATE OR REPLACE FUNCTION cleanup_avatar_performance_data()
RETURNS VOID AS $$
BEGIN
  -- Remove performance logs older than 30 days
  DELETE FROM avatar_query_performance 
  WHERE executed_at < NOW() - INTERVAL '30 days';
  
  -- Analyze tables for better query planning
  ANALYZE avatars;
  ANALYZE posts;
  ANALYZE follows;
  ANALYZE avatar_stats_mv;
END;
$$ LANGUAGE plpgsql;

-- Grant necessary permissions
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated;
GRANT SELECT ON avatar_stats_mv TO authenticated;
GRANT INSERT ON avatar_query_performance TO authenticated;

-- Create a scheduled job to refresh materialized view (if pg_cron is available)
-- SELECT cron.schedule('refresh-avatar-stats', '*/5 * * * *', 'SELECT refresh_avatar_stats_mv();');

COMMIT;