-- Deploy RPC Functions to Supabase
-- Execute this script in your Supabase SQL Editor or via CLI

-- Step 1: Ensure the database schema is ready
-- Make sure you have the required tables: posts, likes, users

-- Step 2: Deploy the RPC functions
\i database_rpc_functions.sql

-- Step 3: Verify deployment
SELECT 
    proname as function_name,
    proowner::regrole as owner,
    prokind as function_type,
    proargnames as argument_names,
    prosecdef as security_definer
FROM pg_proc 
WHERE proname IN (
    'increment_view_count',
    'increment_likes_count', 
    'decrement_likes_count',
    'get_post_interaction_status'
);

-- Step 4: Test the functions (replace with actual post ID)
-- SELECT increment_view_count('YOUR_POST_ID_HERE');
-- SELECT get_post_interaction_status('YOUR_POST_ID_HERE');

-- If you see the functions listed above, deployment was successful!
-- The security_definer column should be 't' (true) for all functions.
