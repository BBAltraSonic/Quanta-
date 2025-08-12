-- RPC Functions for View/Like Counters with RLS-safe Security Definer
-- These functions provide secure, atomic operations for updating counters
-- with proper authentication and authorization checks

-- Function to increment view count with security definer
CREATE OR REPLACE FUNCTION increment_view_count(target_post_id UUID)
RETURNS JSON AS $$
DECLARE
    result_data JSON;
    post_exists BOOLEAN;
    updated_views INTEGER;
BEGIN
    -- Check if user is authenticated
    IF auth.uid() IS NULL THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Authentication required',
            'code', 'AUTH_REQUIRED'
        );
    END IF;

    -- Check if post exists and is active
    SELECT EXISTS(
        SELECT 1 FROM public.posts 
        WHERE id = target_post_id AND is_active = true
    ) INTO post_exists;

    IF NOT post_exists THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Post not found or inactive',
            'code', 'POST_NOT_FOUND'
        );
    END IF;

    -- Increment view count atomically
    UPDATE public.posts 
    SET views_count = views_count + 1,
        updated_at = NOW()
    WHERE id = target_post_id AND is_active = true
    RETURNING views_count INTO updated_views;

    -- Return success response
    RETURN json_build_object(
        'success', true,
        'data', json_build_object(
            'post_id', target_post_id,
            'views_count', updated_views
        )
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Failed to increment view count: ' || SQLERRM,
            'code', 'UPDATE_FAILED'
        );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to increment likes count with security definer
CREATE OR REPLACE FUNCTION increment_likes_count(target_post_id UUID)
RETURNS JSON AS $$
DECLARE
    result_data JSON;
    post_exists BOOLEAN;
    already_liked BOOLEAN;
    updated_likes INTEGER;
    user_uuid UUID;
BEGIN
    -- Get authenticated user ID
    user_uuid := auth.uid();
    
    -- Check if user is authenticated
    IF user_uuid IS NULL THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Authentication required',
            'code', 'AUTH_REQUIRED'
        );
    END IF;

    -- Check if post exists and is active
    SELECT EXISTS(
        SELECT 1 FROM public.posts 
        WHERE id = target_post_id AND is_active = true
    ) INTO post_exists;

    IF NOT post_exists THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Post not found or inactive',
            'code', 'POST_NOT_FOUND'
        );
    END IF;

    -- Check if user already liked this post
    SELECT EXISTS(
        SELECT 1 FROM public.likes 
        WHERE user_id = user_uuid AND post_id = target_post_id
    ) INTO already_liked;

    IF already_liked THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Post already liked by user',
            'code', 'ALREADY_LIKED'
        );
    END IF;

    -- Insert like record and increment counter atomically
    INSERT INTO public.likes (user_id, post_id)
    VALUES (user_uuid, target_post_id);

    -- Get updated likes count
    SELECT likes_count INTO updated_likes
    FROM public.posts 
    WHERE id = target_post_id;

    -- Return success response
    RETURN json_build_object(
        'success', true,
        'data', json_build_object(
            'post_id', target_post_id,
            'likes_count', updated_likes,
            'user_liked', true
        )
    );

EXCEPTION
    WHEN unique_violation THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Post already liked by user',
            'code', 'ALREADY_LIKED'
        );
    WHEN OTHERS THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Failed to increment likes count: ' || SQLERRM,
            'code', 'UPDATE_FAILED'
        );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to decrement likes count with security definer
CREATE OR REPLACE FUNCTION decrement_likes_count(target_post_id UUID)
RETURNS JSON AS $$
DECLARE
    result_data JSON;
    post_exists BOOLEAN;
    like_exists BOOLEAN;
    updated_likes INTEGER;
    user_uuid UUID;
BEGIN
    -- Get authenticated user ID
    user_uuid := auth.uid();
    
    -- Check if user is authenticated
    IF user_uuid IS NULL THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Authentication required',
            'code', 'AUTH_REQUIRED'
        );
    END IF;

    -- Check if post exists and is active
    SELECT EXISTS(
        SELECT 1 FROM public.posts 
        WHERE id = target_post_id AND is_active = true
    ) INTO post_exists;

    IF NOT post_exists THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Post not found or inactive',
            'code', 'POST_NOT_FOUND'
        );
    END IF;

    -- Check if user has liked this post
    SELECT EXISTS(
        SELECT 1 FROM public.likes 
        WHERE user_id = user_uuid AND post_id = target_post_id
    ) INTO like_exists;

    IF NOT like_exists THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Post not liked by user',
            'code', 'NOT_LIKED'
        );
    END IF;

    -- Remove like record (triggers will handle counter decrement)
    DELETE FROM public.likes 
    WHERE user_id = user_uuid AND post_id = target_post_id;

    -- Get updated likes count
    SELECT likes_count INTO updated_likes
    FROM public.posts 
    WHERE id = target_post_id;

    -- Return success response
    RETURN json_build_object(
        'success', true,
        'data', json_build_object(
            'post_id', target_post_id,
            'likes_count', updated_likes,
            'user_liked', false
        )
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Failed to decrement likes count: ' || SQLERRM,
            'code', 'UPDATE_FAILED'
        );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get post interaction status for current user
CREATE OR REPLACE FUNCTION get_post_interaction_status(target_post_id UUID)
RETURNS JSON AS $$
DECLARE
    user_uuid UUID;
    user_liked BOOLEAN := false;
    post_data JSON;
BEGIN
    -- Get authenticated user ID
    user_uuid := auth.uid();
    
    -- Check if user is authenticated
    IF user_uuid IS NULL THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Authentication required',
            'code', 'AUTH_REQUIRED'
        );
    END IF;

    -- Check if user has liked this post
    SELECT EXISTS(
        SELECT 1 FROM public.likes 
        WHERE user_id = user_uuid AND post_id = target_post_id
    ) INTO user_liked;

    -- Get post data with counts
    SELECT json_build_object(
        'id', p.id,
        'views_count', p.views_count,
        'likes_count', p.likes_count,
        'comments_count', p.comments_count,
        'user_liked', user_liked
    ) INTO post_data
    FROM public.posts p
    WHERE p.id = target_post_id AND p.is_active = true;

    IF post_data IS NULL THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Post not found or inactive',
            'code', 'POST_NOT_FOUND'
        );
    END IF;

    -- Return success response
    RETURN json_build_object(
        'success', true,
        'data', post_data
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Failed to get interaction status: ' || SQLERRM,
            'code', 'QUERY_FAILED'
        );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions to authenticated users
GRANT EXECUTE ON FUNCTION increment_view_count(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION increment_likes_count(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION decrement_likes_count(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_post_interaction_status(UUID) TO authenticated;

-- Revoke from anonymous users for security
REVOKE EXECUTE ON FUNCTION increment_view_count(UUID) FROM anon;
REVOKE EXECUTE ON FUNCTION increment_likes_count(UUID) FROM anon;
REVOKE EXECUTE ON FUNCTION decrement_likes_count(UUID) FROM anon;
REVOKE EXECUTE ON FUNCTION get_post_interaction_status(UUID) FROM anon;

-- Add comments for documentation
COMMENT ON FUNCTION increment_view_count(UUID) IS 'Safely increments view count for a post. Requires authentication.';
COMMENT ON FUNCTION increment_likes_count(UUID) IS 'Safely increments likes count for a post. Prevents duplicate likes. Requires authentication.';
COMMENT ON FUNCTION decrement_likes_count(UUID) IS 'Safely decrements likes count for a post. Only removes existing likes. Requires authentication.';
COMMENT ON FUNCTION get_post_interaction_status(UUID) IS 'Returns post interaction status including whether current user has liked the post. Requires authentication.';
