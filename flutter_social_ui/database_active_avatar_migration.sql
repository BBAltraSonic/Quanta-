-- Phase 2: Active Avatar Management Migration
-- This migration ensures proper active avatar functionality and RLS policies

-- 1. Ensure active_avatar_id column exists (may already exist from previous migration)
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS active_avatar_id UUID REFERENCES public.avatars(id);

-- 2. Create index for active_avatar_id for better performance
CREATE INDEX IF NOT EXISTS idx_users_active_avatar ON public.users(active_avatar_id);

-- 3. Add constraint to ensure active_avatar_id belongs to the user
ALTER TABLE public.users 
DROP CONSTRAINT IF EXISTS users_active_avatar_owner_check;

ALTER TABLE public.users 
ADD CONSTRAINT users_active_avatar_owner_check 
CHECK (
    active_avatar_id IS NULL OR 
    EXISTS (
        SELECT 1 FROM public.avatars 
        WHERE id = active_avatar_id AND owner_user_id = users.id
    )
);

-- 4. Create function to automatically set first avatar as active when created
CREATE OR REPLACE FUNCTION set_first_avatar_as_active()
RETURNS TRIGGER AS $$
BEGIN
    -- If this is the user's first avatar, set it as active
    IF NOT EXISTS (
        SELECT 1 FROM public.avatars 
        WHERE owner_user_id = NEW.owner_user_id AND id != NEW.id
    ) THEN
        UPDATE public.users 
        SET active_avatar_id = NEW.id 
        WHERE id = NEW.owner_user_id AND active_avatar_id IS NULL;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 5. Create trigger to automatically set first avatar as active
DROP TRIGGER IF EXISTS set_first_avatar_active_trigger ON public.avatars;
CREATE TRIGGER set_first_avatar_active_trigger
    AFTER INSERT ON public.avatars
    FOR EACH ROW EXECUTE FUNCTION set_first_avatar_as_active();

-- 6. Create function to handle avatar deletion and active avatar cleanup
CREATE OR REPLACE FUNCTION cleanup_active_avatar_on_delete()
RETURNS TRIGGER AS $$
BEGIN
    -- If the deleted avatar was the active avatar, set another avatar as active
    IF OLD.id = (SELECT active_avatar_id FROM public.users WHERE id = OLD.owner_user_id) THEN
        UPDATE public.users 
        SET active_avatar_id = (
            SELECT id FROM public.avatars 
            WHERE owner_user_id = OLD.owner_user_id 
            AND id != OLD.id 
            ORDER BY created_at ASC 
            LIMIT 1
        )
        WHERE id = OLD.owner_user_id;
    END IF;
    
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- 7. Create trigger for active avatar cleanup on deletion
DROP TRIGGER IF EXISTS cleanup_active_avatar_trigger ON public.avatars;
CREATE TRIGGER cleanup_active_avatar_trigger
    BEFORE DELETE ON public.avatars
    FOR EACH ROW EXECUTE FUNCTION cleanup_active_avatar_on_delete();

-- 8. Enhanced RLS policy for users to update their active avatar
DROP POLICY IF EXISTS "Users can update their active avatar" ON public.users;
CREATE POLICY "Users can update their active avatar" ON public.users
    FOR UPDATE USING (auth.uid() = id)
    WITH CHECK (
        auth.uid() = id AND (
            active_avatar_id IS NULL OR 
            EXISTS (
                SELECT 1 FROM public.avatars 
                WHERE id = active_avatar_id AND owner_user_id = auth.uid()
            )
        )
    );

-- 9. Create helper function to get user's active avatar
CREATE OR REPLACE FUNCTION get_user_active_avatar(user_uuid UUID)
RETURNS TABLE (
    avatar_id UUID,
    name TEXT,
    bio TEXT,
    avatar_image_url TEXT,
    niche TEXT,
    followers_count INTEGER,
    likes_count INTEGER,
    posts_count INTEGER,
    engagement_rate REAL
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- First try to get the explicitly set active avatar
    RETURN QUERY
    SELECT 
        a.id,
        a.name,
        a.bio,
        a.avatar_image_url,
        a.niche,
        a.followers_count,
        a.likes_count,
        a.posts_count,
        a.engagement_rate
    FROM public.avatars a
    INNER JOIN public.users u ON u.active_avatar_id = a.id
    WHERE u.id = user_uuid;
    
    -- If no active avatar is set, return the first avatar (by creation date)
    IF NOT FOUND THEN
        RETURN QUERY
        SELECT 
            a.id,
            a.name,
            a.bio,
            a.avatar_image_url,
            a.niche,
            a.followers_count,
            a.likes_count,
            a.posts_count,
            a.engagement_rate
        FROM public.avatars a
        WHERE a.owner_user_id = user_uuid
        ORDER BY a.created_at ASC
        LIMIT 1;
    END IF;
END;
$$;

-- 10. Create function to set active avatar (for use by the app)
CREATE OR REPLACE FUNCTION set_user_active_avatar(user_uuid UUID, avatar_uuid UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Verify the avatar belongs to the user
    IF NOT EXISTS (
        SELECT 1 FROM public.avatars 
        WHERE id = avatar_uuid AND owner_user_id = user_uuid
    ) THEN
        RETURN FALSE;
    END IF;
    
    -- Set the active avatar
    UPDATE public.users 
    SET active_avatar_id = avatar_uuid 
    WHERE id = user_uuid;
    
    RETURN TRUE;
END;
$$;

-- 11. Grant permissions for the new functions
GRANT EXECUTE ON FUNCTION get_user_active_avatar(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION set_user_active_avatar(UUID, UUID) TO authenticated;

-- 12. Update any existing users who don't have an active avatar set
UPDATE public.users 
SET active_avatar_id = (
    SELECT id FROM public.avatars 
    WHERE owner_user_id = users.id 
    ORDER BY created_at ASC 
    LIMIT 1
)
WHERE active_avatar_id IS NULL 
AND EXISTS (
    SELECT 1 FROM public.avatars 
    WHERE owner_user_id = users.id
);

-- 13. Add comment for documentation
COMMENT ON COLUMN public.users.active_avatar_id IS 'The currently active avatar for this user - used for profile display and chat interactions';
COMMENT ON FUNCTION get_user_active_avatar(UUID) IS 'Returns the active avatar for a user, or their first avatar if none is set as active';
COMMENT ON FUNCTION set_user_active_avatar(UUID, UUID) IS 'Sets the active avatar for a user, ensuring the avatar belongs to them';
