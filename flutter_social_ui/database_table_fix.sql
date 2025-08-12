-- Fix table name mismatches between schema and actual database
-- This script handles both scenarios: whether tables exist with old names or new names

-- Check if post_comments table exists and rename it to comments if needed
DO $$ 
BEGIN
    -- If post_comments exists but comments doesn't, rename it
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'post_comments' AND table_schema = 'public')
       AND NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'comments' AND table_schema = 'public') THEN
        ALTER TABLE public.post_comments RENAME TO comments;
        RAISE NOTICE 'Renamed post_comments table to comments';
    END IF;
    
    -- If post_likes exists but likes doesn't, rename it  
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'post_likes' AND table_schema = 'public')
       AND NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'likes' AND table_schema = 'public') THEN
        ALTER TABLE public.post_likes RENAME TO likes;
        RAISE NOTICE 'Renamed post_likes table to likes';
    END IF;
END $$;

-- Ensure comments table has the correct structure
ALTER TABLE public.comments 
ADD COLUMN IF NOT EXISTS post_id UUID REFERENCES public.posts(id) ON DELETE CASCADE,
ADD COLUMN IF NOT EXISTS parent_comment_id UUID REFERENCES public.comments(id) ON DELETE CASCADE,
ADD COLUMN IF NOT EXISTS likes_count INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS is_ai_generated BOOLEAN DEFAULT false;

-- Create comment_likes table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.comment_likes (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    comment_id UUID REFERENCES public.comments(id) ON DELETE CASCADE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    UNIQUE(user_id, comment_id)
);

-- Add missing indexes
CREATE INDEX IF NOT EXISTS idx_comments_post ON public.comments(post_id);
CREATE INDEX IF NOT EXISTS idx_comments_parent ON public.comments(parent_comment_id);
CREATE INDEX IF NOT EXISTS idx_comment_likes_user ON public.comment_likes(user_id);
CREATE INDEX IF NOT EXISTS idx_comment_likes_comment ON public.comment_likes(comment_id);

-- Enable RLS
ALTER TABLE public.comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.comment_likes ENABLE ROW LEVEL SECURITY;

-- Add RLS policies for comments (if they don't exist)
DROP POLICY IF EXISTS "Users can view all comments" ON public.comments;
CREATE POLICY "Users can view all comments" ON public.comments FOR SELECT USING (true);

DROP POLICY IF EXISTS "Authenticated users can create comments" ON public.comments;
CREATE POLICY "Authenticated users can create comments" ON public.comments 
    FOR INSERT WITH CHECK (auth.uid() = user_id OR auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Users can update their own comments" ON public.comments;
CREATE POLICY "Users can update their own comments" ON public.comments 
    FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own comments" ON public.comments;
CREATE POLICY "Users can delete their own comments" ON public.comments 
    FOR DELETE USING (auth.uid() = user_id);

-- Add RLS policies for comment_likes
DROP POLICY IF EXISTS "Users can view all comment likes" ON public.comment_likes;
CREATE POLICY "Users can view all comment likes" ON public.comment_likes FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can create their own comment likes" ON public.comment_likes;
CREATE POLICY "Users can create their own comment likes" ON public.comment_likes 
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own comment likes" ON public.comment_likes;
CREATE POLICY "Users can delete their own comment likes" ON public.comment_likes 
    FOR DELETE USING (auth.uid() = user_id);

-- Update or create the stats function
CREATE OR REPLACE FUNCTION update_avatar_stats()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF TG_TABLE_NAME = 'follows' THEN
            UPDATE public.avatars SET followers_count = followers_count + 1 WHERE id = NEW.avatar_id;
        ELSIF TG_TABLE_NAME = 'likes' THEN
            UPDATE public.posts SET likes_count = likes_count + 1 WHERE id = NEW.post_id;
            UPDATE public.avatars SET likes_count = likes_count + 1 
            WHERE id = (SELECT avatar_id FROM public.posts WHERE id = NEW.post_id);
        ELSIF TG_TABLE_NAME = 'comment_likes' THEN
            UPDATE public.comments SET likes_count = likes_count + 1 WHERE id = NEW.comment_id;
        END IF;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        IF TG_TABLE_NAME = 'follows' THEN
            UPDATE public.avatars SET followers_count = followers_count - 1 WHERE id = OLD.avatar_id;
        ELSIF TG_TABLE_NAME = 'likes' THEN
            UPDATE public.posts SET likes_count = likes_count - 1 WHERE id = OLD.post_id;
            UPDATE public.avatars SET likes_count = likes_count - 1 
            WHERE id = (SELECT avatar_id FROM public.posts WHERE id = OLD.post_id);
        ELSIF TG_TABLE_NAME = 'comment_likes' THEN
            UPDATE public.comments SET likes_count = likes_count - 1 WHERE id = OLD.comment_id;
        END IF;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create triggers
DROP TRIGGER IF EXISTS update_comment_likes_stats ON public.comment_likes;
CREATE TRIGGER update_comment_likes_stats 
    AFTER INSERT OR DELETE ON public.comment_likes
    FOR EACH ROW EXECUTE FUNCTION update_avatar_stats();
