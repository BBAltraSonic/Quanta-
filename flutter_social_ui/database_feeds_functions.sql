-- Deprecated in favor of JSON-returning, RLS-safe RPCs in database_rpc_functions.sql
-- Keep this file for reference only. Do not deploy overlapping function names.

-- Function to increment likes count
-- DO NOT DEPLOY: superseded by increment_likes_count(target_post_id UUID) returning JSON

-- Function to decrement likes count
-- DO NOT DEPLOY: superseded by decrement_likes_count(target_post_id UUID) returning JSON

-- Function to increment comments count
-- DO NOT DEPLOY: add JSON-returning version in database_comments_functions.sql

-- Function to increment view count
-- DO NOT DEPLOY: superseded by increment_view_count(target_post_id UUID) returning JSON

-- Function to get trending posts (optional - can be called from Dart)
CREATE OR REPLACE FUNCTION get_trending_posts(page_limit INTEGER DEFAULT 10, page_offset INTEGER DEFAULT 0)
RETURNS TABLE(
  id UUID,
  avatar_id UUID,
  video_url TEXT,
  image_url TEXT,
  caption TEXT,
  hashtags TEXT[],
  views_count INTEGER,
  likes_count INTEGER,
  comments_count INTEGER,
  is_active BOOLEAN,
  created_at TIMESTAMP WITH TIME ZONE,
  updated_at TIMESTAMP WITH TIME ZONE,
  metadata JSONB,
  trending_score NUMERIC
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.id,
    p.avatar_id,
    p.video_url,
    p.image_url,
    p.caption,
    p.hashtags,
    p.views_count,
    p.likes_count,
    p.comments_count,
    p.is_active,
    p.created_at,
    p.updated_at,
    p.metadata,
    -- Calculate trending score based on engagement and recency
    (
      (p.likes_count * 1.0 + p.comments_count * 2.0 + COALESCE(p.views_count, 0) * 0.1) /
      GREATEST(EXTRACT(EPOCH FROM (NOW() - p.created_at)) / 3600.0, 1.0)
    )::NUMERIC as trending_score
  FROM public.posts p
  WHERE p.is_active = true 
    AND p.video_url IS NOT NULL
    AND p.video_url != ''
  ORDER BY trending_score DESC, p.created_at DESC
  LIMIT page_limit
  OFFSET page_offset;
END;
$$ LANGUAGE plpgsql;

-- Create indexes for better performance if they don't exist
CREATE INDEX IF NOT EXISTS idx_posts_video_active ON public.posts(is_active, video_url) WHERE video_url IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_posts_trending ON public.posts(likes_count DESC, comments_count DESC, created_at DESC) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_likes_user_post ON public.likes(user_id, post_id);
CREATE INDEX IF NOT EXISTS idx_follows_user_avatar ON public.follows(user_id, avatar_id);
CREATE INDEX IF NOT EXISTS idx_comments_post_created ON public.comments(post_id, created_at DESC);

-- Ensure RLS policies allow the functions to work
-- (These should already exist from the schema, but adding for completeness)

-- Grant execute permissions on functions
GRANT EXECUTE ON FUNCTION increment_likes_count(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION decrement_likes_count(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION increment_comments_count(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION increment_view_count(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_trending_posts(INTEGER, INTEGER) TO authenticated;
