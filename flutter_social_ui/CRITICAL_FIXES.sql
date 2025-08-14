-- CRITICAL DATABASE SCHEMA FIXES
-- Execute this in your Supabase SQL Editor to resolve Flutter app runtime errors
-- URL: https://neyfqiauyxfurfhdtrug.supabase.co/project/_/sql

-- ===============================
-- FIX 1: Add user_id column to posts table
-- ===============================
-- This fixes: "Failed to get user posts: column posts.user_id does not exist"
ALTER TABLE public.posts 
ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES public.users(id) ON DELETE CASCADE;

-- Create index for performance
CREATE INDEX IF NOT EXISTS idx_posts_user_id ON public.posts(user_id);

-- Populate user_id for existing posts based on avatar ownership
UPDATE public.posts 
SET user_id = avatars.owner_user_id
FROM public.avatars 
WHERE posts.avatar_id = avatars.id 
AND posts.user_id IS NULL;

-- Create trigger to auto-populate user_id for new posts
CREATE OR REPLACE FUNCTION set_post_user_id()
RETURNS TRIGGER AS $$
BEGIN
    SELECT owner_user_id INTO NEW.user_id 
    FROM public.avatars 
    WHERE id = NEW.avatar_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_post_user_id_trigger ON public.posts;
CREATE TRIGGER set_post_user_id_trigger
    BEFORE INSERT OR UPDATE ON public.posts
    FOR EACH ROW
    EXECUTE FUNCTION set_post_user_id();

-- ===============================
-- FIX 2: Add event_data column to analytics_events
-- ===============================
-- This fixes: "Could not find the 'event_data' column of 'analytics_events'"
ALTER TABLE public.analytics_events 
ADD COLUMN IF NOT EXISTS event_data JSONB;

-- Sync existing properties to event_data
UPDATE public.analytics_events 
SET event_data = properties 
WHERE event_data IS NULL AND properties IS NOT NULL;

-- Create trigger to keep event_data and properties in sync
CREATE OR REPLACE FUNCTION sync_analytics_event_data()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.properties IS NOT NULL THEN
        NEW.event_data := NEW.properties;
    END IF;
    IF NEW.event_data IS NOT NULL THEN
        NEW.properties := NEW.event_data;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS sync_analytics_event_data_trigger ON public.analytics_events;
CREATE TRIGGER sync_analytics_event_data_trigger
    BEFORE INSERT OR UPDATE ON public.analytics_events
    FOR EACH ROW
    EXECUTE FUNCTION sync_analytics_event_data();

-- ===============================
-- FIX 3: Create user_read_messages table
-- ===============================
-- This fixes: "relation 'public.user_read_messages' does not exist"
CREATE TABLE IF NOT EXISTS public.user_read_messages (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    message_id UUID NOT NULL,
    read_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    message_type TEXT DEFAULT 'notification',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    UNIQUE(user_id, message_id, message_type)
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_user_read_messages_user_id ON public.user_read_messages(user_id);
CREATE INDEX IF NOT EXISTS idx_user_read_messages_message_id ON public.user_read_messages(message_id);

-- Enable Row Level Security
ALTER TABLE public.user_read_messages ENABLE ROW LEVEL SECURITY;

-- Create RLS policy
CREATE POLICY "Users can manage own read messages" ON public.user_read_messages
    FOR ALL USING (auth.uid() = user_id);

-- Create helper function for unread count
CREATE OR REPLACE FUNCTION get_unread_count(target_user_id UUID)
RETURNS INTEGER AS $$
BEGIN
    -- Placeholder function - returns 0 for now
    -- Customize this based on your actual notification system
    RETURN 0;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION get_unread_count(UUID) TO authenticated;

-- ===============================
-- FIX 4: Ensure views_count column exists
-- ===============================
ALTER TABLE public.posts 
ADD COLUMN IF NOT EXISTS views_count INTEGER DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_posts_views_count ON public.posts(views_count);

-- ===============================
-- VERIFICATION
-- ===============================
-- Check that all required columns and tables exist
DO $$
DECLARE
    missing_items TEXT[] := ARRAY[]::TEXT[];
BEGIN
    -- Check posts.user_id
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'posts' AND column_name = 'user_id') THEN
        missing_items := array_append(missing_items, 'posts.user_id');
    END IF;
    
    -- Check analytics_events.event_data
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'analytics_events' AND column_name = 'event_data') THEN
        missing_items := array_append(missing_items, 'analytics_events.event_data');
    END IF;
    
    -- Check user_read_messages table
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables 
                   WHERE table_name = 'user_read_messages') THEN
        missing_items := array_append(missing_items, 'user_read_messages table');
    END IF;
    
    -- Check posts.views_count
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'posts' AND column_name = 'views_count') THEN
        missing_items := array_append(missing_items, 'posts.views_count');
    END IF;
    
    IF array_length(missing_items, 1) > 0 THEN
        RAISE EXCEPTION 'Still missing: %', array_to_string(missing_items, ', ');
    ELSE
        RAISE NOTICE '✅ SUCCESS: All critical schema fixes have been applied!';
        RAISE NOTICE '🔄 You can now restart your Flutter app';
        RAISE NOTICE '📱 The following errors should be resolved:';
        RAISE NOTICE '   - posts.user_id does not exist';
        RAISE NOTICE '   - event_data column not found';
        RAISE NOTICE '   - user_read_messages does not exist';
    END IF;
END $$;
