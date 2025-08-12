-- Quanta Platform Database Schema
-- This file contains all the SQL commands needed to set up the Supabase database

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table (extends Supabase auth.users)
CREATE TABLE public.users (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    email TEXT NOT NULL UNIQUE,
    username TEXT NOT NULL UNIQUE,
    display_name TEXT,
    profile_image_url TEXT,
    role TEXT NOT NULL DEFAULT 'creator' CHECK (role IN ('creator', 'viewer', 'admin')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    metadata JSONB DEFAULT '{}'
);

-- Avatars table
CREATE TABLE public.avatars (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    owner_user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    name TEXT NOT NULL,
    bio TEXT NOT NULL,
    backstory TEXT,
    niche TEXT NOT NULL CHECK (niche IN ('fashion', 'fitness', 'comedy', 'tech', 'music', 'art', 'cooking', 'travel', 'gaming', 'education', 'lifestyle', 'business', 'other')),
    personality_traits TEXT[] NOT NULL,
    avatar_image_url TEXT,
    voice_style TEXT,
    personality_prompt TEXT NOT NULL,
    followers_count INTEGER DEFAULT 0,
    likes_count INTEGER DEFAULT 0,
    posts_count INTEGER DEFAULT 0,
    engagement_rate REAL DEFAULT 0.0,
    is_active BOOLEAN DEFAULT true,
    allow_autonomous_posting BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    metadata JSONB DEFAULT '{}'
);

-- Posts/Videos table
CREATE TABLE public.posts (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    avatar_id UUID REFERENCES public.avatars(id) ON DELETE CASCADE NOT NULL,
    video_url TEXT,
    image_url TEXT,
    caption TEXT,
    hashtags TEXT[] DEFAULT '{}',
    views_count INTEGER DEFAULT 0,
    likes_count INTEGER DEFAULT 0,
    comments_count INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    metadata JSONB DEFAULT '{}'
);

-- Comments table
CREATE TABLE public.comments (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    post_id UUID REFERENCES public.posts(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    avatar_id UUID REFERENCES public.avatars(id) ON DELETE CASCADE,
    text TEXT NOT NULL,
    is_ai_generated BOOLEAN DEFAULT false,
    parent_comment_id UUID REFERENCES public.comments(id) ON DELETE CASCADE,
    likes_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    
    -- Either user_id or avatar_id must be set, but not both
    CONSTRAINT comments_author_check CHECK (
        (user_id IS NOT NULL AND avatar_id IS NULL) OR 
        (user_id IS NULL AND avatar_id IS NOT NULL)
    )
);

-- Chat sessions table
CREATE TABLE public.chat_sessions (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    avatar_id UUID REFERENCES public.avatars(id) ON DELETE CASCADE NOT NULL,
    is_active BOOLEAN DEFAULT true,
    last_message_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    metadata JSONB DEFAULT '{}'
);

-- Chat messages table
CREATE TABLE public.chat_messages (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    chat_session_id UUID REFERENCES public.chat_sessions(id) ON DELETE CASCADE NOT NULL,
    sender_user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    sender_avatar_id UUID REFERENCES public.avatars(id) ON DELETE CASCADE,
    message_text TEXT NOT NULL,
    is_ai_generated BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    metadata JSONB DEFAULT '{}',
    
    -- Either sender_user_id or sender_avatar_id must be set, but not both
    CONSTRAINT chat_messages_sender_check CHECK (
        (sender_user_id IS NOT NULL AND sender_avatar_id IS NULL) OR 
        (sender_user_id IS NULL AND sender_avatar_id IS NOT NULL)
    )
);

-- Follows table (users following avatars)
CREATE TABLE public.follows (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    avatar_id UUID REFERENCES public.avatars(id) ON DELETE CASCADE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    
    -- Unique constraint to prevent duplicate follows
    UNIQUE(user_id, avatar_id)
);

-- Likes table (users liking posts)
CREATE TABLE public.likes (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    post_id UUID REFERENCES public.posts(id) ON DELETE CASCADE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    
    -- Unique constraint to prevent duplicate likes
    UNIQUE(user_id, post_id)
);

-- Comment likes table (users liking comments)
CREATE TABLE public.comment_likes (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    comment_id UUID REFERENCES public.comments(id) ON DELETE CASCADE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    
    -- Unique constraint to prevent duplicate likes
    UNIQUE(user_id, comment_id)
);

-- Create indexes for better performance
CREATE INDEX idx_users_username ON public.users(username);
CREATE INDEX idx_users_email ON public.users(email);
CREATE INDEX idx_avatars_owner ON public.avatars(owner_user_id);
CREATE INDEX idx_avatars_niche ON public.avatars(niche);
CREATE INDEX idx_posts_avatar ON public.posts(avatar_id);
CREATE INDEX idx_posts_created_at ON public.posts(created_at DESC);
CREATE INDEX idx_comments_post ON public.comments(post_id);
CREATE INDEX idx_comments_created_at ON public.comments(created_at DESC);
CREATE INDEX idx_chat_sessions_user_avatar ON public.chat_sessions(user_id, avatar_id);
CREATE INDEX idx_chat_messages_session ON public.chat_messages(chat_session_id);
CREATE INDEX idx_chat_messages_created_at ON public.chat_messages(created_at DESC);
CREATE INDEX idx_follows_user ON public.follows(user_id);
CREATE INDEX idx_follows_avatar ON public.follows(avatar_id);
CREATE INDEX idx_likes_user ON public.likes(user_id);
CREATE INDEX idx_likes_post ON public.likes(post_id);
CREATE INDEX idx_comment_likes_user ON public.comment_likes(user_id);
CREATE INDEX idx_comment_likes_comment ON public.comment_likes(comment_id);

-- Create updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Add updated_at triggers to relevant tables
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON public.users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_avatars_updated_at BEFORE UPDATE ON public.avatars
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_posts_updated_at BEFORE UPDATE ON public.posts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_comments_updated_at BEFORE UPDATE ON public.comments
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_chat_sessions_updated_at BEFORE UPDATE ON public.chat_sessions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Row Level Security (RLS) Policies

-- Enable RLS on all tables
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.avatars ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.comment_likes ENABLE ROW LEVEL SECURITY;

-- Users policies
CREATE POLICY "Users can view their own profile" ON public.users
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile" ON public.users
    FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can view other users' public info" ON public.users
    FOR SELECT USING (true);

-- Avatars policies
CREATE POLICY "Users can view all avatars" ON public.avatars
    FOR SELECT USING (true);

CREATE POLICY "Users can create their own avatars" ON public.avatars
    FOR INSERT WITH CHECK (auth.uid() = owner_user_id);

CREATE POLICY "Users can update their own avatars" ON public.avatars
    FOR UPDATE USING (auth.uid() = owner_user_id);

CREATE POLICY "Users can delete their own avatars" ON public.avatars
    FOR DELETE USING (auth.uid() = owner_user_id);

-- Posts policies
CREATE POLICY "Users can view all active posts" ON public.posts
    FOR SELECT USING (is_active = true);

CREATE POLICY "Avatar owners can create posts for their avatars" ON public.posts
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.avatars 
            WHERE id = avatar_id AND owner_user_id = auth.uid()
        )
    );

CREATE POLICY "Avatar owners can update their avatar's posts" ON public.posts
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.avatars 
            WHERE id = avatar_id AND owner_user_id = auth.uid()
        )
    );

CREATE POLICY "Avatar owners can delete their avatar's posts" ON public.posts
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM public.avatars 
            WHERE id = avatar_id AND owner_user_id = auth.uid()
        )
    );

-- Comments policies
CREATE POLICY "Users can view all comments" ON public.comments
    FOR SELECT USING (true);

CREATE POLICY "Authenticated users can create comments" ON public.comments
    FOR INSERT WITH CHECK (auth.uid() = user_id OR auth.uid() IS NOT NULL);

CREATE POLICY "Users can update their own comments" ON public.comments
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own comments" ON public.comments
    FOR DELETE USING (auth.uid() = user_id);

-- Chat sessions policies
CREATE POLICY "Users can view their own chat sessions" ON public.chat_sessions
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can create their own chat sessions" ON public.chat_sessions
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own chat sessions" ON public.chat_sessions
    FOR UPDATE USING (auth.uid() = user_id);

-- Chat messages policies
CREATE POLICY "Users can view messages in their chat sessions" ON public.chat_messages
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.chat_sessions 
            WHERE id = chat_session_id AND user_id = auth.uid()
        )
    );

CREATE POLICY "Users can create messages in their chat sessions" ON public.chat_messages
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.chat_sessions 
            WHERE id = chat_session_id AND user_id = auth.uid()
        )
    );

-- Follows policies
CREATE POLICY "Users can view all follows" ON public.follows
    FOR SELECT USING (true);

CREATE POLICY "Users can create their own follows" ON public.follows
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own follows" ON public.follows
    FOR DELETE USING (auth.uid() = user_id);

-- Likes policies
CREATE POLICY "Users can view all likes" ON public.likes
    FOR SELECT USING (true);

CREATE POLICY "Users can create their own likes" ON public.likes
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own likes" ON public.likes
    FOR DELETE USING (auth.uid() = user_id);

-- Comment likes policies
CREATE POLICY "Users can view all comment likes" ON public.comment_likes
    FOR SELECT USING (true);

CREATE POLICY "Users can create their own comment likes" ON public.comment_likes
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own comment likes" ON public.comment_likes
    FOR DELETE USING (auth.uid() = user_id);

-- Functions for updating counters (called by triggers)
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

-- Create triggers for updating stats
CREATE TRIGGER update_avatar_followers_stats 
    AFTER INSERT OR DELETE ON public.follows
    FOR EACH ROW EXECUTE FUNCTION update_avatar_stats();

CREATE TRIGGER update_avatar_likes_stats 
    AFTER INSERT OR DELETE ON public.likes
    FOR EACH ROW EXECUTE FUNCTION update_avatar_stats();

CREATE TRIGGER update_comment_likes_stats 
    AFTER INSERT OR DELETE ON public.comment_likes
    FOR EACH ROW EXECUTE FUNCTION update_avatar_stats();

-- Storage bucket for media files
INSERT INTO storage.buckets (id, name, public) 
VALUES ('avatars', 'avatars', true);

INSERT INTO storage.buckets (id, name, public) 
VALUES ('posts', 'posts', true);

-- Storage policies
CREATE POLICY "Avatar images are publicly accessible" ON storage.objects
    FOR SELECT USING (bucket_id = 'avatars');

CREATE POLICY "Users can upload their own avatar images" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'avatars' AND 
        auth.uid()::text = (storage.foldername(name))[1]
    );

CREATE POLICY "Users can update their own avatar images" ON storage.objects
    FOR UPDATE USING (
        bucket_id = 'avatars' AND 
        auth.uid()::text = (storage.foldername(name))[1]
    );

CREATE POLICY "Users can delete their own avatar images" ON storage.objects
    FOR DELETE USING (
        bucket_id = 'avatars' AND 
        auth.uid()::text = (storage.foldername(name))[1]
    );

CREATE POLICY "Post media is publicly accessible" ON storage.objects
    FOR SELECT USING (bucket_id = 'posts');

CREATE POLICY "Avatar owners can upload post media" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'posts' AND 
        EXISTS (
            SELECT 1 FROM public.avatars 
            WHERE owner_user_id = auth.uid() AND 
                  id::text = (storage.foldername(name))[1]
        )
    );

-- Sample data (optional - for testing)
-- Uncomment the following lines to insert sample data

-- INSERT INTO public.users (id, email, username, display_name) VALUES
-- ('550e8400-e29b-41d4-a716-446655440000', 'demo@quanta.ai', 'demo_user', 'Demo User');

-- INSERT INTO public.avatars (owner_user_id, name, bio, niche, personality_traits, personality_prompt) VALUES
-- ('550e8400-e29b-41d4-a716-446655440000', 'AI Assistant', 'I am a helpful AI assistant focused on technology and productivity.', 'tech', ARRAY['friendly', 'professional', 'helpful'], 'You are AI Assistant, a tech-focused virtual influencer...');
