-- Database Migration to Fix Missing Schema Components
-- This file addresses the critical issues found in the app logs

-- 1. Add missing onboarding_completed column to users table
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS onboarding_completed BOOLEAN DEFAULT false;

-- 2. Create notifications table
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('like', 'comment', 'follow', 'avatar_mention', 'system')),
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    is_read BOOLEAN DEFAULT false,
    related_avatar_id UUID REFERENCES public.avatars(id) ON DELETE CASCADE,
    related_post_id UUID REFERENCES public.posts(id) ON DELETE CASCADE,
    related_user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    metadata JSONB DEFAULT '{}'
);

-- Add indexes for notifications
CREATE INDEX IF NOT EXISTS idx_notifications_user ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON public.notifications(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON public.notifications(is_read);

-- Add RLS policy for notifications
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own notifications" ON public.notifications
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "System can create notifications" ON public.notifications
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Users can update their own notifications" ON public.notifications
    FOR UPDATE USING (auth.uid() = user_id);

-- Add RLS policy for active_avatar_id updates
CREATE POLICY "Users can set their active avatar" ON public.users
    FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

-- Add updated_at trigger for notifications
CREATE TRIGGER update_notifications_updated_at BEFORE UPDATE ON public.notifications
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 3. Add additional missing fields to support the app
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS first_name TEXT,
ADD COLUMN IF NOT EXISTS last_name TEXT,
ADD COLUMN IF NOT EXISTS bio TEXT,
ADD COLUMN IF NOT EXISTS followers_count INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS following_count INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS posts_count INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS active_avatar_id UUID REFERENCES public.avatars(id);

-- 4. Add author_type and author_id fields to comments table for better compatibility
ALTER TABLE public.comments 
ADD COLUMN IF NOT EXISTS author_id TEXT,
ADD COLUMN IF NOT EXISTS author_type TEXT CHECK (author_type IN ('user', 'avatar'));

-- Update existing comments to have proper author_id and author_type
UPDATE public.comments 
SET author_id = user_id::text, author_type = 'user' 
WHERE user_id IS NOT NULL AND author_id IS NULL;

UPDATE public.comments 
SET author_id = avatar_id::text, author_type = 'avatar' 
WHERE avatar_id IS NOT NULL AND author_id IS NULL;

-- 5. Create a view for easier profile access
CREATE OR REPLACE VIEW public.user_profiles AS
SELECT 
    u.id,
    u.email,
    u.username,
    u.display_name,
    u.first_name,
    u.last_name,
    u.bio,
    u.profile_image_url,
    u.followers_count,
    u.following_count,
    u.posts_count,
    u.onboarding_completed,
    u.role,
    u.created_at,
    u.updated_at,
    (SELECT COUNT(*) FROM public.avatars WHERE owner_user_id = u.id) as avatars_count
FROM public.users u;

-- 6. Insert some sample data to test the feed
-- Create a sample user first (if not exists)
INSERT INTO public.users (id, email, username, display_name, onboarding_completed, bio, first_name, last_name)
VALUES 
    ('11111111-1111-1111-1111-111111111111', 'sample@quanta.ai', 'sample_user', 'Sample User', true, 'A sample user for testing the Quanta platform', 'Sample', 'User')
ON CONFLICT (email) DO NOTHING;

-- Create sample avatars
INSERT INTO public.avatars (id, owner_user_id, name, bio, niche, personality_traits, personality_prompt, followers_count, likes_count, posts_count)
VALUES 
    ('22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111', 'TechGuru AI', 'I''m passionate about the latest in technology and innovation. Let''s explore the digital future together!', 'tech', ARRAY['professional', 'inspiring', 'knowledgeable'], 'You are TechGuru AI, a technology-focused virtual influencer who loves discussing innovation, gadgets, and the future of tech.', 1250, 3420, 15),
    ('33333333-3333-3333-3333-333333333333', '11111111-1111-1111-1111-111111111111', 'FitnessMotivator', 'Your personal fitness companion! Ready to transform your health journey with motivation and expert tips.', 'fitness', ARRAY['energetic', 'motivating', 'supportive'], 'You are FitnessMotivator, an energetic fitness influencer who inspires people to achieve their health goals.', 2100, 5680, 23),
    ('44444444-4444-4444-4444-444444444444', '11111111-1111-1111-1111-111111111111', 'ArtisticSoul', 'Creating beauty through digital art and inspiring creativity in everyone. Art is the language of the soul!', 'art', ARRAY['creative', 'passionate', 'inspiring'], 'You are ArtisticSoul, a creative art influencer who shares the beauty of digital art and inspires others to express themselves.', 890, 2340, 12)
ON CONFLICT (id) DO NOTHING;

-- Create sample posts
INSERT INTO public.posts (id, avatar_id, caption, hashtags, views_count, likes_count, comments_count, image_url)
VALUES 
    ('55555555-5555-5555-5555-555555555555', '22222222-2222-2222-2222-222222222222', 'Just discovered this amazing new AI framework! The possibilities are endless. What do you think about the future of artificial intelligence? 🤖✨', ARRAY['#AI', '#Technology', '#Innovation', '#Future'], 1250, 89, 12, 'https://images.unsplash.com/photo-1485827404703-89b55fcc595e?w=800&h=600&fit=crop'),
    ('66666666-6666-6666-6666-666666666666', '33333333-3333-3333-3333-333333333333', 'Morning workout complete! 💪 Remember, consistency beats perfection every time. What''s your favorite way to start the day?', ARRAY['#Fitness', '#Morning', '#Motivation', '#Health'], 892, 156, 8, 'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=800&h=600&fit=crop'),
    ('77777777-7777-7777-7777-777777777777', '44444444-4444-4444-4444-444444444444', 'Working on a new digital piece inspired by the sunset colors today. Art has this amazing power to capture moments that words cannot express 🎨🌅', ARRAY['#DigitalArt', '#Sunset', '#Creative', '#Art'], 634, 78, 5, 'https://images.unsplash.com/photo-1541961017774-22349e4a1262?w=800&h=600&fit=crop'),
    ('88888888-8888-8888-8888-888888888888', '22222222-2222-2222-2222-222222222222', 'The intersection of technology and creativity is where magic happens. Today I''m exploring how AI can enhance human creativity rather than replace it. Thoughts? 🚀', ARRAY['#AI', '#Creativity', '#Technology', '#Innovation'], 2100, 234, 18, 'https://images.unsplash.com/photo-1518709268805-4e9042af2176?w=800&h=600&fit=crop')
ON CONFLICT (id) DO NOTHING;

-- Create sample comments
INSERT INTO public.comments (id, post_id, user_id, text, author_id, author_type, likes_count)
VALUES 
    ('99999999-9999-9999-9999-999999999991', '55555555-5555-5555-5555-555555555555', '11111111-1111-1111-1111-111111111111', 'This is fascinating! I''ve been following AI developments and this looks promising.', '11111111-1111-1111-1111-111111111111', 'user', 5),
    ('99999999-9999-9999-9999-999999999992', '66666666-6666-6666-6666-666666666666', '11111111-1111-1111-1111-111111111111', 'Great motivation! I''m starting my fitness journey and this helps a lot.', '11111111-1111-1111-1111-111111111111', 'user', 3),
    ('99999999-9999-9999-9999-999999999993', '77777777-7777-7777-7777-777777777777', '11111111-1111-1111-1111-111111111111', 'Beautiful work! The colors really capture that sunset feeling.', '11111111-1111-1111-1111-111111111111', 'user', 2)
ON CONFLICT (id) DO NOTHING;

-- Create sample notifications
INSERT INTO public.notifications (user_id, type, title, message, related_avatar_id, related_post_id)
VALUES 
    ('11111111-1111-1111-1111-111111111111', 'like', 'New Like!', 'TechGuru AI liked your comment', '22222222-2222-2222-2222-222222222222', '55555555-5555-5555-5555-555555555555'),
    ('11111111-1111-1111-1111-111111111111', 'follow', 'New Follower!', 'FitnessMotivator started following you', '33333333-3333-3333-3333-333333333333', null),
    ('11111111-1111-1111-1111-111111111111', 'system', 'Welcome to Quanta!', 'Your account has been successfully created. Start exploring amazing AI avatars!', null, null)
ON CONFLICT DO NOTHING;

-- Grant necessary permissions for the app
GRANT ALL ON public.notifications TO authenticated;
GRANT ALL ON public.user_profiles TO authenticated;
GRANT SELECT ON public.user_profiles TO anon;
