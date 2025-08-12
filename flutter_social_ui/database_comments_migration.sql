-- Migration to add comment likes functionality and fix comments table
-- Run this if you get "column comments.post_id does not exist" error

-- First, let's check if the comments table exists and what columns it has
-- You may need to run this manually in your Supabase SQL editor

-- Create comment_likes table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.comment_likes (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    comment_id UUID REFERENCES public.comments(id) ON DELETE CASCADE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    
    -- Unique constraint to prevent duplicate likes
    UNIQUE(user_id, comment_id)
);

-- Add indexes for comment_likes if they don't exist
CREATE INDEX IF NOT EXISTS idx_comment_likes_user ON public.comment_likes(user_id);
CREATE INDEX IF NOT EXISTS idx_comment_likes_comment ON public.comment_likes(comment_id);

-- Enable RLS on comment_likes
ALTER TABLE public.comment_likes ENABLE ROW LEVEL SECURITY;

-- Add RLS policies for comment_likes
DROP POLICY IF EXISTS "Users can view all comment likes" ON public.comment_likes;
CREATE POLICY "Users can view all comment likes" ON public.comment_likes
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can create their own comment likes" ON public.comment_likes;
CREATE POLICY "Users can create their own comment likes" ON public.comment_likes
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own comment likes" ON public.comment_likes;
CREATE POLICY "Users can delete their own comment likes" ON public.comment_likes
    FOR DELETE USING (auth.uid() = user_id);

-- Update the stats function to handle comment likes
CREATE OR REPLACE FUNCTION update_avatar_stats()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        -- Update follower count for avatars
        IF TG_TABLE_NAME = 'follows' THEN
            UPDATE public.avatars 
            SET followers_count = followers_count + 1 
            WHERE id = NEW.avatar_id;
        END IF;
        
        -- Update likes count for posts and avatars
        IF TG_TABLE_NAME = 'likes' THEN
            UPDATE public.posts 
            SET likes_count = likes_count + 1 
            WHERE id = NEW.post_id;
            
            UPDATE public.avatars 
            SET likes_count = likes_count + 1 
            WHERE id = (SELECT avatar_id FROM public.posts WHERE id = NEW.post_id);
        END IF;
        
        -- Update likes count for comments
        IF TG_TABLE_NAME = 'comment_likes' THEN
            UPDATE public.comments 
            SET likes_count = likes_count + 1 
            WHERE id = NEW.comment_id;
        END IF;
        
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        -- Update follower count for avatars
        IF TG_TABLE_NAME = 'follows' THEN
            UPDATE public.avatars 
            SET followers_count = followers_count - 1 
            WHERE id = OLD.avatar_id;
        END IF;
        
        -- Update likes count for posts and avatars
        IF TG_TABLE_NAME = 'likes' THEN
            UPDATE public.posts 
            SET likes_count = likes_count - 1 
            WHERE id = OLD.post_id;
            
            UPDATE public.avatars 
            SET likes_count = likes_count - 1 
            WHERE id = (SELECT avatar_id FROM public.posts WHERE id = OLD.post_id);
        END IF;
        
        -- Update likes count for comments
        IF TG_TABLE_NAME = 'comment_likes' THEN
            UPDATE public.comments 
            SET likes_count = likes_count - 1 
            WHERE id = OLD.comment_id;
        END IF;
        
        RETURN OLD;
    END IF;
    
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for comment likes stats
DROP TRIGGER IF EXISTS update_comment_likes_stats ON public.comment_likes;
CREATE TRIGGER update_comment_likes_stats 
    AFTER INSERT OR DELETE ON public.comment_likes
    FOR EACH ROW EXECUTE FUNCTION update_avatar_stats();
