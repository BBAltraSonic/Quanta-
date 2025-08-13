-- ========================================
-- COPY AND PASTE THIS ENTIRE SCRIPT INTO SUPABASE SQL EDITOR
-- ========================================

-- ========================================
-- MESSAGES & PUBLIC CHAT ENTRIES SETUP
-- ========================================

-- Migration for Public Chat Entries
-- This enables users to make specific chat messages/conversations public
-- for avatar showcasing or creator portfolio purposes

-- Create public_chat_entries table
CREATE TABLE IF NOT EXISTS public.public_chat_entries (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    session_id UUID NOT NULL REFERENCES public.chat_sessions(id) ON DELETE CASCADE,
    message_id UUID NOT NULL REFERENCES public.chat_messages(id) ON DELETE CASCADE,
    avatar_id UUID NOT NULL REFERENCES public.avatars(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    message_text TEXT NOT NULL,
    avatar_response TEXT,
    is_public BOOLEAN DEFAULT true,
    visibility TEXT CHECK (visibility IN ('avatar', 'creator', 'private')) DEFAULT 'private',
    metadata JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Ensure uniqueness per message (prevent duplicate public entries)
    UNIQUE(message_id, user_id)
);

-- Create user_read_messages table for read receipts
CREATE TABLE IF NOT EXISTS public.user_read_messages (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    session_id UUID NOT NULL REFERENCES public.chat_sessions(id) ON DELETE CASCADE,
    message_id UUID NOT NULL REFERENCES public.chat_messages(id) ON DELETE CASCADE,
    read_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Ensure uniqueness per user per message
    UNIQUE(user_id, message_id)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_public_chat_entries_avatar_id ON public.public_chat_entries(avatar_id);
CREATE INDEX IF NOT EXISTS idx_public_chat_entries_user_id ON public.public_chat_entries(user_id);
CREATE INDEX IF NOT EXISTS idx_public_chat_entries_visibility ON public.public_chat_entries(visibility);
CREATE INDEX IF NOT EXISTS idx_public_chat_entries_is_public ON public.public_chat_entries(is_public);
CREATE INDEX IF NOT EXISTS idx_public_chat_entries_created_at ON public.public_chat_entries(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_user_read_messages_user_id ON public.user_read_messages(user_id);
CREATE INDEX IF NOT EXISTS idx_user_read_messages_session_id ON public.user_read_messages(session_id);
CREATE INDEX IF NOT EXISTS idx_user_read_messages_read_at ON public.user_read_messages(read_at DESC);

-- Enable RLS
ALTER TABLE public.public_chat_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_read_messages ENABLE ROW LEVEL SECURITY;

-- RLS Policies for public_chat_entries

-- Users can see their own public entries and any entries marked as public
CREATE POLICY "Users can view own public entries and public ones" ON public.public_chat_entries
FOR SELECT USING (
    user_id = auth.uid() 
    OR (is_public = true AND visibility IN ('avatar', 'creator'))
);

-- Users can only insert their own public entries
CREATE POLICY "Users can insert own public entries" ON public.public_chat_entries
FOR INSERT WITH CHECK (
    user_id = auth.uid()
);

-- Users can only update their own public entries
CREATE POLICY "Users can update own public entries" ON public.public_chat_entries
FOR UPDATE USING (
    user_id = auth.uid()
) WITH CHECK (
    user_id = auth.uid()
);

-- Users can only delete their own public entries
CREATE POLICY "Users can delete own public entries" ON public.public_chat_entries
FOR DELETE USING (
    user_id = auth.uid()
);

-- RLS Policies for user_read_messages

-- Users can only see their own read messages
CREATE POLICY "Users can view own read messages" ON public.user_read_messages
FOR SELECT USING (
    user_id = auth.uid()
);

-- Users can only insert their own read messages
CREATE POLICY "Users can insert own read messages" ON public.user_read_messages
FOR INSERT WITH CHECK (
    user_id = auth.uid()
);

-- Users can update their own read messages
CREATE POLICY "Users can update own read messages" ON public.user_read_messages
FOR UPDATE USING (
    user_id = auth.uid()
) WITH CHECK (
    user_id = auth.uid()
);

-- Update triggers
CREATE OR REPLACE FUNCTION update_public_chat_entries_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_public_chat_entries_updated_at
    BEFORE UPDATE ON public.public_chat_entries
    FOR EACH ROW
    EXECUTE FUNCTION update_public_chat_entries_updated_at();

-- Grant permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON public.public_chat_entries TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_read_messages TO authenticated;
GRANT USAGE ON SCHEMA public TO authenticated;

-- Add comments for documentation
COMMENT ON TABLE public.public_chat_entries IS 'Public chat entries that can be showcased for avatars or creator portfolios';
COMMENT ON COLUMN public.public_chat_entries.visibility IS 'Visibility level: avatar (show on avatar profile), creator (show on creator profile), private (not shown publicly)';
COMMENT ON COLUMN public.public_chat_entries.is_public IS 'Whether the entry is publicly visible';
COMMENT ON COLUMN public.public_chat_entries.message_text IS 'The user message text';
COMMENT ON COLUMN public.public_chat_entries.avatar_response IS 'The AI avatar response (if any)';

COMMENT ON TABLE public.user_read_messages IS 'Tracks which messages users have read for unread count calculation';
COMMENT ON COLUMN public.user_read_messages.read_at IS 'Timestamp when the user read the message';

-- Create view for public chat entries with avatar info
CREATE OR REPLACE VIEW public.public_chat_entries_with_avatar AS
SELECT 
    pce.*,
    a.name as avatar_name,
    a.avatar_image_url,
    a.niche,
    a.bio as avatar_bio
FROM public.public_chat_entries pce
JOIN public.avatars a ON pce.avatar_id = a.id
WHERE pce.is_public = true;

GRANT SELECT ON public.public_chat_entries_with_avatar TO authenticated;

-- Add indexes for the view
CREATE INDEX IF NOT EXISTS idx_public_chat_entries_with_avatar_visibility 
ON public.public_chat_entries(visibility, is_public, created_at DESC) 
WHERE is_public = true;

-- ========================================
-- POSTS & LIKES FUNCTIONS
-- ========================================

-- Function to increment view count with security definer
CREATE OR REPLACE FUNCTION increment_view_count(target_post_id UUID)
RETURNS JSON AS $$
DECLARE
    result_data JSON;
    post_exists BOOLEAN;
    updated_views INTEGER;
BEGIN
    -- Check if user is authenticated
    IF auth.uid() IS NULL THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Authentication required',
            'code', 'AUTH_REQUIRED'
        );
    END IF;

    -- Check if post exists and is active
    SELECT EXISTS(
        SELECT 1 FROM public.posts 
        WHERE id = target_post_id AND is_active = true
    ) INTO post_exists;

    IF NOT post_exists THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Post not found or inactive',
            'code', 'POST_NOT_FOUND'
        );
    END IF;

    -- Increment view count atomically
    UPDATE public.posts 
    SET views_count = views_count + 1,
        updated_at = NOW()
    WHERE id = target_post_id AND is_active = true
    RETURNING views_count INTO updated_views;

    -- Return success response
    RETURN json_build_object(
        'success', true,
        'data', json_build_object(
            'post_id', target_post_id,
            'views_count', updated_views
        )
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Failed to increment view count: ' || SQLERRM,
            'code', 'UPDATE_FAILED'
        );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to increment likes count with security definer
CREATE OR REPLACE FUNCTION increment_likes_count(target_post_id UUID)
RETURNS JSON AS $$
DECLARE
    result_data JSON;
    post_exists BOOLEAN;
    already_liked BOOLEAN;
    updated_likes INTEGER;
    user_uuid UUID;
BEGIN
    -- Get authenticated user ID
    user_uuid := auth.uid();
    
    -- Check if user is authenticated
    IF user_uuid IS NULL THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Authentication required',
            'code', 'AUTH_REQUIRED'
        );
    END IF;

    -- Check if post exists and is active
    SELECT EXISTS(
        SELECT 1 FROM public.posts 
        WHERE id = target_post_id AND is_active = true
    ) INTO post_exists;

    IF NOT post_exists THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Post not found or inactive',
            'code', 'POST_NOT_FOUND'
        );
    END IF;

    -- Check if user already liked this post
    SELECT EXISTS(
        SELECT 1 FROM public.likes 
        WHERE user_id = user_uuid AND post_id = target_post_id
    ) INTO already_liked;

    IF already_liked THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Post already liked by user',
            'code', 'ALREADY_LIKED'
        );
    END IF;

    -- Insert like record and increment counter atomically
    INSERT INTO public.likes (user_id, post_id)
    VALUES (user_uuid, target_post_id);

    -- Get updated likes count
    SELECT likes_count INTO updated_likes
    FROM public.posts 
    WHERE id = target_post_id;

    -- Return success response
    RETURN json_build_object(
        'success', true,
        'data', json_build_object(
            'post_id', target_post_id,
            'likes_count', updated_likes,
            'user_liked', true
        )
    );

EXCEPTION
    WHEN unique_violation THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Post already liked by user',
            'code', 'ALREADY_LIKED'
        );
    WHEN OTHERS THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Failed to increment likes count: ' || SQLERRM,
            'code', 'UPDATE_FAILED'
        );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to decrement likes count with security definer
CREATE OR REPLACE FUNCTION decrement_likes_count(target_post_id UUID)
RETURNS JSON AS $$
DECLARE
    result_data JSON;
    post_exists BOOLEAN;
    like_exists BOOLEAN;
    updated_likes INTEGER;
    user_uuid UUID;
BEGIN
    -- Get authenticated user ID
    user_uuid := auth.uid();
    
    -- Check if user is authenticated
    IF user_uuid IS NULL THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Authentication required',
            'code', 'AUTH_REQUIRED'
        );
    END IF;

    -- Check if post exists and is active
    SELECT EXISTS(
        SELECT 1 FROM public.posts 
        WHERE id = target_post_id AND is_active = true
    ) INTO post_exists;

    IF NOT post_exists THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Post not found or inactive',
            'code', 'POST_NOT_FOUND'
        );
    END IF;

    -- Check if user has liked this post
    SELECT EXISTS(
        SELECT 1 FROM public.likes 
        WHERE user_id = user_uuid AND post_id = target_post_id
    ) INTO like_exists;

    IF NOT like_exists THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Post not liked by user',
            'code', 'NOT_LIKED'
        );
    END IF;

    -- Remove like record (triggers will handle counter decrement)
    DELETE FROM public.likes 
    WHERE user_id = user_uuid AND post_id = target_post_id;

    -- Get updated likes count
    SELECT likes_count INTO updated_likes
    FROM public.posts 
    WHERE id = target_post_id;

    -- Return success response
    RETURN json_build_object(
        'success', true,
        'data', json_build_object(
            'post_id', target_post_id,
            'likes_count', updated_likes,
            'user_liked', false
        )
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Failed to decrement likes count: ' || SQLERRM,
            'code', 'UPDATE_FAILED'
        );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get post interaction status for current user
CREATE OR REPLACE FUNCTION get_post_interaction_status(target_post_id UUID)
RETURNS JSON AS $$
DECLARE
    user_uuid UUID;
    user_liked BOOLEAN := false;
    post_data JSON;
BEGIN
    -- Get authenticated user ID
    user_uuid := auth.uid();
    
    -- Check if user is authenticated
    IF user_uuid IS NULL THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Authentication required',
            'code', 'AUTH_REQUIRED'
        );
    END IF;

    -- Check if user has liked this post
    SELECT EXISTS(
        SELECT 1 FROM public.likes 
        WHERE user_id = user_uuid AND post_id = target_post_id
    ) INTO user_liked;

    -- Get post data with counts
    SELECT json_build_object(
        'id', p.id,
        'views_count', p.views_count,
        'likes_count', p.likes_count,
        'comments_count', p.comments_count,
        'user_liked', user_liked
    ) INTO post_data
    FROM public.posts p
    WHERE p.id = target_post_id AND p.is_active = true;

    IF post_data IS NULL THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Post not found or inactive',
            'code', 'POST_NOT_FOUND'
        );
    END IF;

    -- Return success response
    RETURN json_build_object(
        'success', true,
        'data', post_data
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Failed to get interaction status: ' || SQLERRM,
            'code', 'QUERY_FAILED'
        );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions to authenticated users
GRANT EXECUTE ON FUNCTION increment_view_count(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION increment_likes_count(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION decrement_likes_count(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_post_interaction_status(UUID) TO authenticated;

-- Revoke from anonymous users for security
REVOKE EXECUTE ON FUNCTION increment_view_count(UUID) FROM anon;
REVOKE EXECUTE ON FUNCTION increment_likes_count(UUID) FROM anon;
REVOKE EXECUTE ON FUNCTION decrement_likes_count(UUID) FROM anon;
REVOKE EXECUTE ON FUNCTION get_post_interaction_status(UUID) FROM anon;

-- Add comments for documentation
COMMENT ON FUNCTION increment_view_count(UUID) IS 'Safely increments view count for a post. Requires authentication.';
COMMENT ON FUNCTION increment_likes_count(UUID) IS 'Safely increments likes count for a post. Prevents duplicate likes. Requires authentication.';
COMMENT ON FUNCTION decrement_likes_count(UUID) IS 'Safely decrements likes count for a post. Only removes existing likes. Requires authentication.';
COMMENT ON FUNCTION get_post_interaction_status(UUID) IS 'Returns post interaction status including whether current user has liked the post. Requires authentication.';

-- ========================================
-- DEPLOYMENT VERIFICATION
-- ========================================

-- Run this query to verify the functions were created successfully:
SELECT 
    proname as function_name,
    proowner::regrole as owner,
    prokind as function_type,
    prosecdef as security_definer
FROM pg_proc 
WHERE proname IN (
    'increment_view_count',
    'increment_likes_count', 
    'decrement_likes_count',
    'get_post_interaction_status'
)
ORDER BY proname;
