-- Verification script to check if the comment system database setup is correct
-- Run this after running the main setup script

-- Check if all required tables exist
SELECT 
    'Table Status' as check_type,
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'comments' AND table_schema = 'public') 
        THEN '✅ comments table exists'
        ELSE '❌ comments table missing'
    END as comments_table,
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'comment_likes' AND table_schema = 'public') 
        THEN '✅ comment_likes table exists'
        ELSE '❌ comment_likes table missing'
    END as comment_likes_table,
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'likes' AND table_schema = 'public') 
        THEN '✅ likes table exists'
        ELSE '❌ likes table missing'
    END as likes_table;

-- Check if required columns exist in comments table
SELECT 
    'Comments Table Columns' as check_type,
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'comments' AND column_name = 'post_id' AND table_schema = 'public') 
        THEN '✅ post_id column exists'
        ELSE '❌ post_id column missing'
    END as post_id_column,
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'comments' AND column_name = 'parent_comment_id' AND table_schema = 'public') 
        THEN '✅ parent_comment_id column exists'
        ELSE '❌ parent_comment_id column missing'
    END as parent_comment_id_column,
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'comments' AND column_name = 'likes_count' AND table_schema = 'public') 
        THEN '✅ likes_count column exists'
        ELSE '❌ likes_count column missing'
    END as likes_count_column;

-- Check if RLS is enabled
SELECT 
    'Row Level Security' as check_type,
    CASE 
        WHEN (SELECT relrowsecurity FROM pg_class WHERE relname = 'comments') 
        THEN '✅ RLS enabled on comments'
        ELSE '❌ RLS not enabled on comments'
    END as comments_rls,
    CASE 
        WHEN (SELECT relrowsecurity FROM pg_class WHERE relname = 'comment_likes') 
        THEN '✅ RLS enabled on comment_likes'
        ELSE '❌ RLS not enabled on comment_likes'
    END as comment_likes_rls;

-- Check if key indexes exist
SELECT 
    'Indexes' as check_type,
    CASE 
        WHEN EXISTS (SELECT 1 FROM pg_indexes WHERE tablename = 'comments' AND indexname = 'idx_comments_post') 
        THEN '✅ comments post_id index exists'
        ELSE '❌ comments post_id index missing'
    END as comments_post_index,
    CASE 
        WHEN EXISTS (SELECT 1 FROM pg_indexes WHERE tablename = 'comment_likes' AND indexname = 'idx_comment_likes_comment') 
        THEN '✅ comment_likes comment_id index exists'
        ELSE '❌ comment_likes comment_id index missing'
    END as comment_likes_index;

-- Check if triggers exist
SELECT 
    'Triggers' as check_type,
    CASE 
        WHEN EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_comment_likes_stats') 
        THEN '✅ comment_likes trigger exists'
        ELSE '❌ comment_likes trigger missing'
    END as comment_likes_trigger;

-- Show table row counts (should be 0 for new setup)
SELECT 
    'Row Counts' as check_type,
    (SELECT COUNT(*) FROM public.comments) as comments_count,
    (SELECT COUNT(*) FROM public.comment_likes) as comment_likes_count,
    (SELECT COUNT(*) FROM public.likes) as likes_count;

-- Test query that the app will run (this should not error)
SELECT 'Test Query' as check_type, 'Attempting to run app query...' as status;

-- This is the exact query the app runs - if this works, the app will work
SELECT * FROM public.comments 
WHERE post_id = '00000000-0000-0000-0000-000000000000'  -- dummy UUID
AND parent_comment_id IS NULL
ORDER BY created_at DESC
LIMIT 20;
