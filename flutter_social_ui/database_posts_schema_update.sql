-- Posts table schema update migration
-- Adds missing columns required by PostModel and enforces business rules

-- Add missing columns to posts table
ALTER TABLE public.posts 
ADD COLUMN IF NOT EXISTS type TEXT CHECK (type IN ('image','video')),
ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'published' CHECK (status IN ('draft','published','archived','flagged')),
ADD COLUMN IF NOT EXISTS thumbnail_url TEXT,
ADD COLUMN IF NOT EXISTS shares_count INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS engagement_rate REAL DEFAULT 0.0;

-- Create indexes for new columns
CREATE INDEX IF NOT EXISTS idx_posts_type ON public.posts(type);
CREATE INDEX IF NOT EXISTS idx_posts_status ON public.posts(status);

-- Create function to calculate engagement rate
CREATE OR REPLACE FUNCTION calculate_engagement_rate(post_id UUID)
RETURNS REAL AS $$
DECLARE
    total_interactions INTEGER;
    views INTEGER;
    engagement REAL;
BEGIN
    -- Get total views
    SELECT views_count INTO views FROM public.posts WHERE id = post_id;
    
    -- Calculate total interactions (likes + comments + shares)
    SELECT 
        (likes_count + comments_count + shares_count) INTO total_interactions
    FROM public.posts WHERE id = post_id;
    
    -- Calculate engagement rate (interactions / views)
    IF views > 0 THEN
        engagement := (total_interactions::REAL / views::REAL) * 100;
    ELSE
        engagement := 0.0;
    END IF;
    
    RETURN LEAST(engagement, 100.0); -- Cap at 100%
END;
$$ LANGUAGE plpgsql;

-- Create trigger to update engagement rate when stats change
CREATE OR REPLACE FUNCTION update_post_engagement_rate()
RETURNS TRIGGER AS $$
BEGIN
    NEW.engagement_rate := calculate_engagement_rate(NEW.id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add trigger for engagement rate updates
DROP TRIGGER IF EXISTS update_post_engagement_trigger ON public.posts;
CREATE TRIGGER update_post_engagement_trigger
    BEFORE UPDATE OF likes_count, comments_count, shares_count, views_count
    ON public.posts
    FOR EACH ROW
    EXECUTE FUNCTION update_post_engagement_rate();

-- Update avatar posts_count function to include type filtering
CREATE OR REPLACE FUNCTION update_avatar_posts_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        -- Increment posts count when a new post is created
        UPDATE public.avatars 
        SET posts_count = posts_count + 1 
        WHERE id = NEW.avatar_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        -- Decrement posts count when a post is deleted
        UPDATE public.avatars 
        SET posts_count = posts_count - 1 
        WHERE id = OLD.avatar_id;
        RETURN OLD;
    ELSIF TG_OP = 'UPDATE' THEN
        -- Handle status changes (archived/deleted posts shouldn't count)
        IF OLD.status = 'published' AND NEW.status != 'published' THEN
            UPDATE public.avatars 
            SET posts_count = posts_count - 1 
            WHERE id = NEW.avatar_id;
        ELSIF OLD.status != 'published' AND NEW.status = 'published' THEN
            UPDATE public.avatars 
            SET posts_count = posts_count + 1 
            WHERE id = NEW.avatar_id;
        END IF;
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Add trigger for posts count updates
DROP TRIGGER IF EXISTS update_avatar_posts_count_trigger ON public.posts;
CREATE TRIGGER update_avatar_posts_count_trigger
    AFTER INSERT OR UPDATE OR DELETE ON public.posts
    FOR EACH ROW
    EXECUTE FUNCTION update_avatar_posts_count();

-- Add constraint to ensure either image_url or video_url is set based on type
ALTER TABLE public.posts 
ADD CONSTRAINT posts_media_type_check 
CHECK (
    (type = 'image' AND image_url IS NOT NULL AND video_url IS NULL) OR
    (type = 'video' AND video_url IS NOT NULL AND image_url IS NULL) OR
    (type IS NULL AND (image_url IS NOT NULL OR video_url IS NOT NULL))
);

-- Create shares table if it doesn't exist (for shares_count)
CREATE TABLE IF NOT EXISTS public.post_shares (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    post_id UUID REFERENCES public.posts(id) ON DELETE CASCADE NOT NULL,
    platform TEXT, -- 'internal', 'twitter', 'facebook', etc.
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    metadata JSONB DEFAULT '{}',
    
    -- Unique constraint to prevent duplicate shares per platform
    UNIQUE(user_id, post_id, platform)
);

-- Enable RLS on shares table
ALTER TABLE public.post_shares ENABLE ROW LEVEL SECURITY;

-- Shares policies
CREATE POLICY "Users can view all shares" ON public.post_shares
    FOR SELECT USING (true);

CREATE POLICY "Users can create their own shares" ON public.post_shares
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own shares" ON public.post_shares
    FOR DELETE USING (auth.uid() = user_id);

-- Create indexes for shares table
CREATE INDEX IF NOT EXISTS idx_post_shares_user ON public.post_shares(user_id);
CREATE INDEX IF NOT EXISTS idx_post_shares_post ON public.post_shares(post_id);
CREATE INDEX IF NOT EXISTS idx_post_shares_platform ON public.post_shares(platform);

-- Update the existing stats function to handle shares
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
        
        -- Update shares count for posts
        IF TG_TABLE_NAME = 'post_shares' THEN
            UPDATE public.posts 
            SET shares_count = shares_count + 1 
            WHERE id = NEW.post_id;
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
        
        -- Update shares count for posts
        IF TG_TABLE_NAME = 'post_shares' THEN
            UPDATE public.posts 
            SET shares_count = shares_count - 1 
            WHERE id = OLD.post_id;
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

-- Add trigger for share stats
CREATE TRIGGER update_post_shares_stats 
    AFTER INSERT OR DELETE ON public.post_shares
    FOR EACH ROW EXECUTE FUNCTION update_avatar_stats();

-- Update storage policy for posts bucket to include thumbnails
CREATE POLICY "Avatar owners can upload thumbnails" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'posts' AND 
        name LIKE '%thumbnail%' AND
        EXISTS (
            SELECT 1 FROM public.avatars 
            WHERE owner_user_id = auth.uid() AND 
                  id::text = (storage.foldername(name))[1]
        )
    );
