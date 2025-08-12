-- Safety Features Database Migration
-- Migrating user safety features from SharedPreferences to Supabase tables
-- This includes user_blocks, reports, and user_mutes tables with RLS

-- Create reports table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.reports (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    post_id UUID REFERENCES public.posts(id) ON DELETE CASCADE,
    comment_id UUID REFERENCES public.comments(id) ON DELETE CASCADE,
    reported_user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    content_type TEXT NOT NULL CHECK (content_type IN ('post', 'comment', 'message', 'profile')),
    report_type TEXT NOT NULL CHECK (report_type IN ('spam', 'inappropriate', 'harassment', 'copyright', 'other')),
    reason TEXT,
    details TEXT,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'reviewed', 'resolved', 'dismissed')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    metadata JSONB DEFAULT '{}',
    
    -- Ensure at least one content reference is provided
    CONSTRAINT reports_content_check CHECK (
        (post_id IS NOT NULL AND comment_id IS NULL) OR
        (post_id IS NULL AND comment_id IS NOT NULL) OR
        (post_id IS NULL AND comment_id IS NULL AND reported_user_id IS NOT NULL)
    )
);

-- Create user_blocks table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.user_blocks (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    blocker_user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    blocked_user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    metadata JSONB DEFAULT '{}',
    
    -- Unique constraint to prevent duplicate blocks
    UNIQUE(blocker_user_id, blocked_user_id),
    
    -- Prevent self-blocking
    CONSTRAINT user_blocks_self_check CHECK (blocker_user_id != blocked_user_id)
);

-- Create user_mutes table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.user_mutes (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    muter_user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    muted_user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    muted_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    duration_minutes INTEGER, -- NULL means indefinite
    expires_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    metadata JSONB DEFAULT '{}',
    
    -- Unique constraint to prevent duplicate mutes
    UNIQUE(muter_user_id, muted_user_id),
    
    -- Prevent self-muting
    CONSTRAINT user_mutes_self_check CHECK (muter_user_id != muted_user_id)
);

-- Create view_events table if it doesn't exist (for analytics)
CREATE TABLE IF NOT EXISTS public.view_events (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    post_id UUID REFERENCES public.posts(id) ON DELETE CASCADE NOT NULL,
    duration_seconds INTEGER DEFAULT 0,
    watch_percentage REAL DEFAULT 0.0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    metadata JSONB DEFAULT '{}'
);

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_reports_user ON public.reports(user_id);
CREATE INDEX IF NOT EXISTS idx_reports_post ON public.reports(post_id);
CREATE INDEX IF NOT EXISTS idx_reports_comment ON public.reports(comment_id);
CREATE INDEX IF NOT EXISTS idx_reports_reported_user ON public.reports(reported_user_id);
CREATE INDEX IF NOT EXISTS idx_reports_status ON public.reports(status);
CREATE INDEX IF NOT EXISTS idx_reports_created_at ON public.reports(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_user_blocks_blocker ON public.user_blocks(blocker_user_id);
CREATE INDEX IF NOT EXISTS idx_user_blocks_blocked ON public.user_blocks(blocked_user_id);
CREATE INDEX IF NOT EXISTS idx_user_blocks_created_at ON public.user_blocks(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_user_mutes_muter ON public.user_mutes(muter_user_id);
CREATE INDEX IF NOT EXISTS idx_user_mutes_muted ON public.user_mutes(muted_user_id);
CREATE INDEX IF NOT EXISTS idx_user_mutes_expires_at ON public.user_mutes(expires_at);
CREATE INDEX IF NOT EXISTS idx_user_mutes_created_at ON public.user_mutes(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_view_events_user ON public.view_events(user_id);
CREATE INDEX IF NOT EXISTS idx_view_events_post ON public.view_events(post_id);
CREATE INDEX IF NOT EXISTS idx_view_events_created_at ON public.view_events(created_at DESC);

-- Enable Row Level Security
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_blocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_mutes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.view_events ENABLE ROW LEVEL SECURITY;

-- Drop existing policies to avoid conflicts
DROP POLICY IF EXISTS "Users can view reports they created" ON public.reports;
DROP POLICY IF EXISTS "Users can create reports" ON public.reports;
DROP POLICY IF EXISTS "Users can update their own reports" ON public.reports;
DROP POLICY IF EXISTS "Admins can manage all reports" ON public.reports;

DROP POLICY IF EXISTS "Users can view blocks they created" ON public.user_blocks;
DROP POLICY IF EXISTS "Users can create blocks" ON public.user_blocks;
DROP POLICY IF EXISTS "Users can delete their own blocks" ON public.user_blocks;

DROP POLICY IF EXISTS "Users can view mutes they created" ON public.user_mutes;
DROP POLICY IF EXISTS "Users can create mutes" ON public.user_mutes;
DROP POLICY IF EXISTS "Users can update their own mutes" ON public.user_mutes;
DROP POLICY IF EXISTS "Users can delete their own mutes" ON public.user_mutes;

DROP POLICY IF EXISTS "Users can view their own view events" ON public.view_events;
DROP POLICY IF EXISTS "Users can create view events" ON public.view_events;

-- Create RLS policies for reports
CREATE POLICY "Users can view reports they created" ON public.reports
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can create reports" ON public.reports
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own reports" ON public.reports
    FOR UPDATE USING (auth.uid() = user_id);

-- Admins can view/manage all reports (for moderation)
CREATE POLICY "Admins can manage all reports" ON public.reports
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE id = auth.uid() AND role IN ('admin', 'moderator')
        )
    );

-- Create RLS policies for user_blocks
CREATE POLICY "Users can view blocks they created" ON public.user_blocks
    FOR SELECT USING (auth.uid() = blocker_user_id);

CREATE POLICY "Users can create blocks" ON public.user_blocks
    FOR INSERT WITH CHECK (auth.uid() = blocker_user_id);

CREATE POLICY "Users can delete their own blocks" ON public.user_blocks
    FOR DELETE USING (auth.uid() = blocker_user_id);

-- Create RLS policies for user_mutes
CREATE POLICY "Users can view mutes they created" ON public.user_mutes
    FOR SELECT USING (auth.uid() = muter_user_id);

CREATE POLICY "Users can create mutes" ON public.user_mutes
    FOR INSERT WITH CHECK (auth.uid() = muter_user_id);

CREATE POLICY "Users can update their own mutes" ON public.user_mutes
    FOR UPDATE USING (auth.uid() = muter_user_id);

CREATE POLICY "Users can delete their own mutes" ON public.user_mutes
    FOR DELETE USING (auth.uid() = muter_user_id);

-- Create RLS policies for view_events
CREATE POLICY "Users can view their own view events" ON public.view_events
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can create view events" ON public.view_events
    FOR INSERT WITH CHECK (auth.uid() = user_id OR user_id IS NULL);

-- Create trigger function to automatically set expires_at for mutes
CREATE OR REPLACE FUNCTION set_mute_expiration()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.duration_minutes IS NOT NULL THEN
        NEW.expires_at = NEW.muted_at + (NEW.duration_minutes || ' minutes')::INTERVAL;
    ELSE
        NEW.expires_at = NULL; -- Indefinite mute
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for mute expiration
DROP TRIGGER IF EXISTS set_mute_expiration_trigger ON public.user_mutes;
CREATE TRIGGER set_mute_expiration_trigger
    BEFORE INSERT OR UPDATE ON public.user_mutes
    FOR EACH ROW EXECUTE FUNCTION set_mute_expiration();

-- Add updated_at triggers
DROP TRIGGER IF EXISTS update_reports_updated_at ON public.reports;
CREATE TRIGGER update_reports_updated_at BEFORE UPDATE ON public.reports
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Create function to clean up expired mutes
CREATE OR REPLACE FUNCTION cleanup_expired_mutes()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM public.user_mutes 
    WHERE expires_at IS NOT NULL AND expires_at < NOW();
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to check if user is muted (with automatic cleanup)
CREATE OR REPLACE FUNCTION is_user_muted(muter_id UUID, muted_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    -- First cleanup expired mutes
    PERFORM cleanup_expired_mutes();
    
    -- Check if user is currently muted
    RETURN EXISTS (
        SELECT 1 FROM public.user_mutes 
        WHERE muter_user_id = muter_id 
        AND muted_user_id = muted_id
        AND (expires_at IS NULL OR expires_at > NOW())
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to check if user is blocked
CREATE OR REPLACE FUNCTION is_user_blocked(blocker_id UUID, blocked_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.user_blocks 
        WHERE blocker_user_id = blocker_id 
        AND blocked_user_id = blocked_id
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add configuration constants for mute durations (in minutes)
COMMENT ON TABLE public.user_mutes IS 'User mute functionality with optional expiration. Common durations: 15min, 60min, 1440min (24h), 10080min (7 days), null (indefinite)';

-- Final status check
DO $$
DECLARE
    tables_created TEXT[];
BEGIN
    -- Check which safety tables now exist
    SELECT array_agg(table_name) INTO tables_created
    FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name IN ('reports', 'user_blocks', 'user_mutes', 'view_events');
    
    RAISE NOTICE 'Safety migration complete! Created/verified tables: %', array_to_string(tables_created, ', ');
    RAISE NOTICE 'Safety features can now be migrated from SharedPreferences to database.';
END $$;
