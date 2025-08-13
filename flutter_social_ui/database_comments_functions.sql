-- Comments counter RPCs (RLS-safe)

CREATE OR REPLACE FUNCTION increment_comments_count(post_id UUID)
RETURNS JSON AS $$
DECLARE updated_comments INTEGER;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Authentication required', 'code', 'AUTH_REQUIRED');
  END IF;

  UPDATE public.posts
  SET comments_count = comments_count + 1,
      updated_at = NOW()
  WHERE id = post_id AND is_active = true
  RETURNING comments_count INTO updated_comments;

  RETURN json_build_object('success', true, 'data', json_build_object('post_id', post_id, 'comments_count', updated_comments));
EXCEPTION
  WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'error', 'Failed to increment comments count: ' || SQLERRM, 'code', 'UPDATE_FAILED');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION decrement_comments_count(post_id UUID)
RETURNS JSON AS $$
DECLARE updated_comments INTEGER;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Authentication required', 'code', 'AUTH_REQUIRED');
  END IF;

  UPDATE public.posts
  SET comments_count = GREATEST(comments_count - 1, 0),
      updated_at = NOW()
  WHERE id = post_id AND is_active = true
  RETURNING comments_count INTO updated_comments;

  RETURN json_build_object('success', true, 'data', json_build_object('post_id', post_id, 'comments_count', updated_comments));
EXCEPTION
  WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'error', 'Failed to decrement comments count: ' || SQLERRM, 'code', 'UPDATE_FAILED');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION increment_comments_count(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION decrement_comments_count(UUID) TO authenticated;
REVOKE EXECUTE ON FUNCTION increment_comments_count(UUID) FROM anon;
REVOKE EXECUTE ON FUNCTION decrement_comments_count(UUID) FROM anon;


