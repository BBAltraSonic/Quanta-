-- Complete Database Setup for Comment System
-- This script handles all scenarios: missing tables, wrong names, missing columns, etc.

-- First, let's check and fix table names
DO $$ 
BEGIN
    -- Rename old table names to new ones if they exist
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'post_comments' AND table_schema = 'public')
       AND NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'comments' AND table_schema = 'public') THEN
        ALTER TABLE public.post_comments RENAME TO comments;
        RAISE NOTICE 'Renamed post_comments to comments';
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'post_likes' AND table_schema = 'public')
       AND NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'likes' AND table_schema = 'public') THEN
        ALTER TABLE public.post_likes RENAME TO likes;
        RAISE NOTICE 'Renamed post_likes to likes';
    END IF;
END $$;

-- Create or ensure comments table has correct structure
CREATE TABLE IF NOT EXISTS public.comments (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    post_id UUID,
    user_id UUID,
    avatar_id UUID,
    text TEXT NOT NULL,
    is_ai_generated BOOLEAN DEFAULT false,
    parent_comment_id UUID,
    likes_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

-- Add missing columns to comments table if they don't exist
ALTER TABLE public.comments 
ADD COLUMN IF NOT EXISTS post_id UUID,
ADD COLUMN IF NOT EXISTS user_id UUID,
ADD COLUMN IF NOT EXISTS avatar_id UUID,
ADD COLUMN IF NOT EXISTS parent_comment_id UUID,
ADD COLUMN IF NOT EXISTS likes_count INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS is_ai_generated BOOLEAN DEFAULT false;

-- Add foreign key constraints if they don't exist
DO $$
BEGIN
    -- Add post_id foreign key
    IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints 
                   WHERE constraint_name = 'comments_post_id_fkey' AND table_name = 'comments') THEN
        ALTER TABLE public.comments 
        ADD CONSTRAINT comments_post_id_fkey 
        FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;
    END IF;
    
    -- Add user_id foreign key
    IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints 
                   WHERE constraint_name = 'comments_user_id_fkey' AND table_name = 'comments') THEN
        ALTER TABLE public.comments 
        ADD CONSTRAINT comments_user_id_fkey 
        FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;
    END IF;
    
    -- Add parent_comment_id foreign key
    IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints 
                   WHERE constraint_name = 'comments_parent_comment_id_fkey' AND table_name = 'comments') THEN
        ALTER TABLE public.comments 
        ADD CONSTRAINT comments_parent_comment_id_fkey 
        FOREIGN KEY (parent_comment_id) REFERENCES public.comments(id) ON DELETE CASCADE;
    END IF;
    
    -- Add author check constraint
    IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints 
                   WHERE constraint_name = 'comments_author_check' AND table_name = 'comments') THEN
        ALTER TABLE public.comments 
        ADD CONSTRAINT comments_author_check CHECK (
            (user_id IS NOT NULL AND avatar_id IS NULL) OR 
            (user_id IS NULL AND avatar_id IS NOT NULL)
        );
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Some constraints may already exist or there may be data conflicts';
END $$;

-- Create likes table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.likes (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID NOT NULL,
    post_id UUID NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    UNIQUE(user_id, post_id)
);

-- Add foreign keys to likes table
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints 
                   WHERE constraint_name = 'likes_user_id_fkey' AND table_name = 'likes') THEN
        ALTER TABLE public.likes 
        ADD CONSTRAINT likes_user_id_fkey 
        FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints 
                   WHERE constraint_name = 'likes_post_id_fkey' AND table_name = 'likes') THEN
        ALTER TABLE public.likes 
        ADD CONSTRAINT likes_post_id_fkey 
        FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Likes table constraints may already exist';
END $$;

-- Create comment_likes table
CREATE TABLE IF NOT EXISTS public.comment_likes (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID NOT NULL,
    comment_id UUID NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    UNIQUE(user_id, comment_id)
);

-- Add foreign keys to comment_likes table
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints 
                   WHERE constraint_name = 'comment_likes_user_id_fkey' AND table_name = 'comment_likes') THEN
        ALTER TABLE public.comment_likes 
        ADD CONSTRAINT comment_likes_user_id_fkey 
        FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints 
                   WHERE constraint_name = 'comment_likes_comment_id_fkey' AND table_name = 'comment_likes') THEN
        ALTER TABLE public.comment_likes 
        ADD CONSTRAINT comment_likes_comment_id_fkey 
        FOREIGN KEY (comment_id) REFERENCES public.comments(id) ON DELETE CASCADE;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Comment_likes table constraints may already exist';
END $$;

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_comments_post ON public.comments(post_id);
CREATE INDEX IF NOT EXISTS idx_comments_parent ON public.comments(parent_comment_id);
CREATE INDEX IF NOT EXISTS idx_comments_created_at ON public.comments(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_likes_user ON public.likes(user_id);
CREATE INDEX IF NOT EXISTS idx_likes_post ON public.likes(post_id);
CREATE INDEX IF NOT EXISTS idx_comment_likes_user ON public.comment_likes(user_id);
CREATE INDEX IF NOT EXISTS idx_comment_likes_comment ON public.comment_likes(comment_id);

-- Enable Row Level Security
ALTER TABLE public.comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.comment_likes ENABLE ROW LEVEL SECURITY;

-- Drop existing policies to avoid conflicts
DROP POLICY IF EXISTS "Users can view all comments" ON public.comments;
DROP POLICY IF EXISTS "Authenticated users can create comments" ON public.comments;
DROP POLICY IF EXISTS "Users can update their own comments" ON public.comments;
DROP POLICY IF EXISTS "Users can delete their own comments" ON public.comments;

DROP POLICY IF EXISTS "Users can view all likes" ON public.likes;
DROP POLICY IF EXISTS "Users can create their own likes" ON public.likes;
DROP POLICY IF EXISTS "Users can delete their own likes" ON public.likes;

DROP POLICY IF EXISTS "Users can view all comment likes" ON public.comment_likes;
DROP POLICY IF EXISTS "Users can create their own comment likes" ON public.comment_likes;
DROP POLICY IF EXISTS "Users can delete their own comment likes" ON public.comment_likes;

-- Create RLS policies for comments
CREATE POLICY "Users can view all comments" ON public.comments
    FOR SELECT USING (true);

CREATE POLICY "Authenticated users can create comments" ON public.comments
    FOR INSERT WITH CHECK (auth.uid() = user_id OR auth.uid() IS NOT NULL);

CREATE POLICY "Users can update their own comments" ON public.comments
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own comments" ON public.comments
    FOR DELETE USING (auth.uid() = user_id);

-- Create RLS policies for likes
CREATE POLICY "Users can view all likes" ON public.likes
    FOR SELECT USING (true);

CREATE POLICY "Users can create their own likes" ON public.likes
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own likes" ON public.likes
    FOR DELETE USING (auth.uid() = user_id);

-- Create RLS policies for comment_likes
CREATE POLICY "Users can view all comment likes" ON public.comment_likes
    FOR SELECT USING (true);

CREATE POLICY "Users can create their own comment likes" ON public.comment_likes
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own comment likes" ON public.comment_likes
    FOR DELETE USING (auth.uid() = user_id);

-- Create or replace the stats update function
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

-- Create triggers (drop first to avoid duplicates)
DROP TRIGGER IF EXISTS update_avatar_followers_stats ON public.follows;
DROP TRIGGER IF EXISTS update_avatar_likes_stats ON public.likes;
DROP TRIGGER IF EXISTS update_comment_likes_stats ON public.comment_likes;

CREATE TRIGGER update_avatar_followers_stats 
    AFTER INSERT OR DELETE ON public.follows
    FOR EACH ROW EXECUTE FUNCTION update_avatar_stats();

CREATE TRIGGER update_avatar_likes_stats 
    AFTER INSERT OR DELETE ON public.likes
    FOR EACH ROW EXECUTE FUNCTION update_avatar_stats();

CREATE TRIGGER update_comment_likes_stats 
    AFTER INSERT OR DELETE ON public.comment_likes
    FOR EACH ROW EXECUTE FUNCTION update_avatar_stats();

-- Create updated_at trigger function if it doesn't exist
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Add updated_at trigger to comments
DROP TRIGGER IF EXISTS update_comments_updated_at ON public.comments;
CREATE TRIGGER update_comments_updated_at BEFORE UPDATE ON public.comments
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Create other necessary tables if they don't exist
CREATE TABLE IF NOT EXISTS public.saved_posts (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    post_id UUID REFERENCES public.posts(id) ON DELETE CASCADE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    UNIQUE(user_id, post_id)
);

CREATE TABLE IF NOT EXISTS public.post_shares (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    post_id UUID REFERENCES public.posts(id) ON DELETE CASCADE NOT NULL,
    message TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

-- Enable RLS on additional tables
ALTER TABLE public.saved_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_shares ENABLE ROW LEVEL SECURITY;

-- Add RLS policies for saved_posts
DROP POLICY IF EXISTS "Users can view all saved posts" ON public.saved_posts;
DROP POLICY IF EXISTS "Users can create their own saved posts" ON public.saved_posts;
DROP POLICY IF EXISTS "Users can delete their own saved posts" ON public.saved_posts;

CREATE POLICY "Users can view all saved posts" ON public.saved_posts FOR SELECT USING (true);
CREATE POLICY "Users can create their own saved posts" ON public.saved_posts FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete their own saved posts" ON public.saved_posts FOR DELETE USING (auth.uid() = user_id);

-- Add RLS policies for post_shares
DROP POLICY IF EXISTS "Users can view all shares" ON public.post_shares;
DROP POLICY IF EXISTS "Users can create their own shares" ON public.post_shares;

CREATE POLICY "Users can view all shares" ON public.post_shares FOR SELECT USING (true);
CREATE POLICY "Users can create their own shares" ON public.post_shares FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Final status check
DO $$
DECLARE
    tables_created TEXT[];
BEGIN
    -- Check which tables now exist
    SELECT array_agg(table_name) INTO tables_created
    FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name IN ('comments', 'comment_likes', 'likes', 'saved_posts', 'post_shares');
    
    RAISE NOTICE 'Database setup complete! Created/verified tables: %', array_to_string(tables_created, ', ');
    RAISE NOTICE 'Comment system should now be fully functional.';
END $$;
