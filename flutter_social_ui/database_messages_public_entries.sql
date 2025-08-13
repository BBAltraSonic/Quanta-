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

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_public_chat_entries_avatar_id ON public.public_chat_entries(avatar_id);
CREATE INDEX IF NOT EXISTS idx_public_chat_entries_user_id ON public.public_chat_entries(user_id);
CREATE INDEX IF NOT EXISTS idx_public_chat_entries_visibility ON public.public_chat_entries(visibility);
CREATE INDEX IF NOT EXISTS idx_public_chat_entries_is_public ON public.public_chat_entries(is_public);
CREATE INDEX IF NOT EXISTS idx_public_chat_entries_created_at ON public.public_chat_entries(created_at DESC);

-- Enable RLS
ALTER TABLE public.public_chat_entries ENABLE ROW LEVEL SECURITY;

-- RLS Policies

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

-- Update trigger for updated_at
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
GRANT USAGE ON SCHEMA public TO authenticated;

-- Add comments for documentation
COMMENT ON TABLE public.public_chat_entries IS 'Public chat entries that can be showcased for avatars or creator portfolios';
COMMENT ON COLUMN public.public_chat_entries.visibility IS 'Visibility level: avatar (show on avatar profile), creator (show on creator profile), private (not shown publicly)';
COMMENT ON COLUMN public.public_chat_entries.is_public IS 'Whether the entry is publicly visible';
COMMENT ON COLUMN public.public_chat_entries.message_text IS 'The user message text';
COMMENT ON COLUMN public.public_chat_entries.avatar_response IS 'The AI avatar response (if any)';

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
