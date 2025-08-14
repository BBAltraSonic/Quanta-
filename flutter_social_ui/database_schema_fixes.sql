-- Database Schema Fixes for App Runtime Errors
-- This script addresses the schema mismatches causing runtime errors

-- ==========================================
-- FIX 1: Posts table - Add user_id column (app expects both user_id and avatar_id)
-- ==========================================

-- Add user_id column to posts table that references the owner of the avatar
ALTER TABLE public.posts 
ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES public.users(id) ON DELETE CASCADE;

-- Create index for the new column
CREATE INDEX IF NOT EXISTS idx_posts_user_id ON public.posts(user_id);

-- Create function to populate user_id based on avatar ownership
CREATE OR REPLACE FUNCTION populate_posts_user_id()
RETURNS VOID AS $$
BEGIN
    UPDATE public.posts 
    SET user_id = avatars.owner_user_id
    FROM public.avatars 
    WHERE posts.avatar_id = avatars.id 
    AND posts.user_id IS NULL;
END;
$$ LANGUAGE plpgsql;

-- Populate existing records
SELECT populate_posts_user_id();

-- Create trigger to automatically set user_id when posts are inserted/updated
CREATE OR REPLACE FUNCTION set_post_user_id()
RETURNS TRIGGER AS $$
BEGIN
    -- Set user_id based on avatar ownership
    SELECT owner_user_id INTO NEW.user_id 
    FROM public.avatars 
    WHERE id = NEW.avatar_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add trigger for automatic user_id population
DROP TRIGGER IF EXISTS set_post_user_id_trigger ON public.posts;
CREATE TRIGGER set_post_user_id_trigger
    BEFORE INSERT OR UPDATE ON public.posts
    FOR EACH ROW
    EXECUTE FUNCTION set_post_user_id();

-- ==========================================
-- FIX 2: Analytics Events - Add event_data column alias/view
-- ==========================================

-- The app expects 'event_data' but the table has 'properties'
-- Add event_data as an alias column
ALTER TABLE public.analytics_events 
ADD COLUMN IF NOT EXISTS event_data JSONB;

-- Create function to sync event_data with properties
CREATE OR REPLACE FUNCTION sync_analytics_event_data()
RETURNS TRIGGER AS $$
BEGIN
    -- Sync properties to event_data for backward compatibility
    IF NEW.properties IS NOT NULL THEN
        NEW.event_data := NEW.properties;
    END IF;
    
    -- Sync event_data to properties (in case app writes to event_data)
    IF NEW.event_data IS NOT NULL THEN
        NEW.properties := NEW.event_data;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add trigger for data synchronization
DROP TRIGGER IF EXISTS sync_analytics_event_data_trigger ON public.analytics_events;
CREATE TRIGGER sync_analytics_event_data_trigger
    BEFORE INSERT OR UPDATE ON public.analytics_events
    FOR EACH ROW
    EXECUTE FUNCTION sync_analytics_event_data();

-- Populate existing records
UPDATE public.analytics_events 
SET event_data = properties 
WHERE event_data IS NULL AND properties IS NOT NULL;

-- ==========================================
-- FIX 3: Missing user_read_messages table
-- ==========================================

-- Create user_read_messages table for notification read tracking
CREATE TABLE IF NOT EXISTS public.user_read_messages (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    message_id UUID NOT NULL, -- This could reference notifications or direct messages
    read_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    message_type TEXT DEFAULT 'notification' CHECK (message_type IN ('notification', 'direct_message', 'system')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    
    -- Prevent duplicate read entries
    UNIQUE(user_id, message_id, message_type)
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_user_read_messages_user_id ON public.user_read_messages(user_id);
CREATE INDEX IF NOT EXISTS idx_user_read_messages_message_id ON public.user_read_messages(message_id);
CREATE INDEX IF NOT EXISTS idx_user_read_messages_type ON public.user_read_messages(message_type);
CREATE INDEX IF NOT EXISTS idx_user_read_messages_read_at ON public.user_read_messages(read_at);

-- Enable RLS
ALTER TABLE public.user_read_messages ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view own read messages" ON public.user_read_messages
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own read messages" ON public.user_read_messages
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own read messages" ON public.user_read_messages
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own read messages" ON public.user_read_messages
    FOR DELETE USING (auth.uid() = user_id);

-- ==========================================
-- FIX 4: Additional helper functions for app compatibility
-- ==========================================

-- Function to get unread message count (what the app is trying to call)
CREATE OR REPLACE FUNCTION get_unread_count(target_user_id UUID)
RETURNS INTEGER AS $$
DECLARE
    total_notifications INTEGER;
    read_notifications INTEGER;
    unread_count INTEGER;
BEGIN
    -- Count total notifications/messages for user
    -- This is a placeholder - adjust based on your actual notification system
    SELECT COUNT(*) INTO total_notifications
    FROM (
        -- Add your actual notification sources here
        SELECT 1 as dummy_notification
        WHERE false -- Placeholder query that returns 0
    ) as notifications;
    
    -- Count read messages
    SELECT COUNT(*) INTO read_notifications
    FROM public.user_read_messages
    WHERE user_id = target_user_id;
    
    unread_count := GREATEST(0, total_notifications - read_notifications);
    
    RETURN unread_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT EXECUTE ON FUNCTION get_unread_count(UUID) TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_read_messages TO authenticated;

-- ==========================================
-- FIX 5: Ensure views_count column exists in posts
-- ==========================================

-- Add views_count if it doesn't exist
ALTER TABLE public.posts 
ADD COLUMN IF NOT EXISTS views_count INTEGER DEFAULT 0;

-- Create index
CREATE INDEX IF NOT EXISTS idx_posts_views_count ON public.posts(views_count);

-- ==========================================
-- VERIFICATION QUERIES
-- ==========================================

-- Verify all columns exist
DO $$
DECLARE
    missing_columns TEXT[] := ARRAY[]::TEXT[];
BEGIN
    -- Check posts.user_id
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'posts' AND column_name = 'user_id') THEN
        missing_columns := array_append(missing_columns, 'posts.user_id');
    END IF;
    
    -- Check analytics_events.event_data
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'analytics_events' AND column_name = 'event_data') THEN
        missing_columns := array_append(missing_columns, 'analytics_events.event_data');
    END IF;
    
    -- Check user_read_messages table
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables 
                   WHERE table_name = 'user_read_messages') THEN
        missing_columns := array_append(missing_columns, 'user_read_messages table');
    END IF;
    
    -- Check posts.views_count
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'posts' AND column_name = 'views_count') THEN
        missing_columns := array_append(missing_columns, 'posts.views_count');
    END IF;
    
    IF array_length(missing_columns, 1) > 0 THEN
        RAISE EXCEPTION 'Missing required columns/tables: %', array_to_string(missing_columns, ', ');
    ELSE
        RAISE NOTICE 'SUCCESS: All required columns and tables are present!';
    END IF;
END $$;

-- Test the functions
SELECT 'Testing get_unread_count function...' as status;
SELECT get_unread_count(gen_random_uuid()) as test_unread_count;

RAISE NOTICE 'Schema fixes completed successfully!';
RAISE NOTICE 'The app should now run without column/table missing errors.';
