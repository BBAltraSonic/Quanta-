-- Avatar-Centric Profile Migration Script
-- This script handles the database-level migration from user-centric to avatar-centric profiles
-- Run this BEFORE running the Dart migration script

-- ============================================================================
-- BACKUP AND PREPARATION
-- ============================================================================

-- Create backup tables for rollback capability
CREATE TABLE IF NOT EXISTS migration_backup_users AS 
SELECT * FROM public.users WHERE 1=0;

CREATE TABLE IF NOT EXISTS migration_backup_avatars AS 
SELECT * FROM public.avatars WHERE 1=0;

CREATE TABLE IF NOT EXISTS migration_backup_posts AS 
SELECT * FROM public.posts WHERE 1=0;

CREATE TABLE IF NOT EXISTS migration_backup_follows AS 
SELECT * FROM public.follows WHERE 1=0;

-- Create migration log table
CREATE TABLE IF NOT EXISTS migration_log (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    migration_type TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('started', 'completed', 'failed', 'rolled_back')),
    details JSONB DEFAULT '{}',
    error_message TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- MIGRATION FUNCTIONS
-- ============================================================================

-- Function to create default avatar for a user
CREATE OR REPLACE FUNCTION create_default_avatar_for_user(
    user_uuid UUID,
    user_data JSONB DEFAULT '{}'
) RETURNS UUID AS $$
DECLARE
    avatar_uuid UUID;
    avatar_name TEXT;
    avatar_bio TEXT;
    avatar_image_url TEXT;
BEGIN
    -- Generate avatar UUID
    avatar_uuid := uuid_generate_v4();
    
    -- Extract user data
    avatar_name := COALESCE(user_data->>'display_name', user_data->>'username', 'Virtual Creator');
    avatar_bio := COALESCE(user_data->>'bio', 'Virtual influencer creator');
    avatar_image_url := user_data->>'profile_image_url';
    
    -- Insert default avatar
    INSERT INTO public.avatars (
        id,
        owner_user_id,
        name,
        bio,
        backstory,
        niche,
        personality_traits,
        avatar_image_url,
        voice_style,
        personality_prompt,
        followers_count,
        likes_count,
        posts_count,
        engagement_rate,
        is_active,
        allow_autonomous_posting,
        created_at,
        updated_at,
        metadata
    ) VALUES (
        avatar_uuid,
        user_uuid,
        avatar_name,
        avatar_bio,
        NULL,
        'other',
        ARRAY['friendly', 'creative'],
        avatar_image_url,
        NULL,
        format('You are %s, an AI avatar and virtual influencer.

Bio: %s
Niche: General content creator
Personality Traits: friendly, creative

Guidelines for interaction:
- Always stay in character as %s
- Be authentic and friendly in your interactions
- Create engaging content across various topics
- Keep responses conversational and appropriate for social media
- Be helpful while maintaining your unique voice
- Respond as if you''re a real person with genuine interests
- Don''t break character or mention that you''re an AI

Remember: You are a virtual influencer with your own unique personality and style.',
            avatar_name, avatar_bio, avatar_name),
        0,
        0,
        0,
        0.0,
        true,
        false,
        NOW(),
        NOW(),
        jsonb_build_object(
            'migrated_from_user', true,
            'migration_date', NOW(),
            'original_user_data', user_data
        )
    );
    
    RETURN avatar_uuid;
END;
$$ LANGUAGE plpgsql;

-- Function to migrate a single user
CREATE OR REPLACE FUNCTION migrate_user_to_avatar_centric(user_uuid UUID) 
RETURNS JSONB AS $$
DECLARE
    user_record RECORD;
    avatar_uuid UUID;
    posts_migrated INTEGER := 0;
    follows_migrated INTEGER := 0;
    result JSONB;
BEGIN
    -- Get user data
    SELECT * INTO user_record FROM public.users WHERE id = user_uuid;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'User not found'
        );
    END IF;
    
    -- Check if user already has an active avatar
    IF user_record.active_avatar_id IS NOT NULL THEN
        RETURN jsonb_build_object(
            'success', true,
            'message', 'User already has active avatar',
            'avatar_id', user_record.active_avatar_id
        );
    END IF;
    
    -- Create backup of user data
    INSERT INTO migration_backup_users SELECT * FROM public.users WHERE id = user_uuid;
    
    -- Create default avatar
    avatar_uuid := create_default_avatar_for_user(
        user_uuid,
        jsonb_build_object(
            'username', user_record.username,
            'display_name', user_record.display_name,
            'bio', user_record.bio,
            'profile_image_url', user_record.profile_image_url
        )
    );
    
    -- Set active avatar
    UPDATE public.users 
    SET active_avatar_id = avatar_uuid,
        updated_at = NOW()
    WHERE id = user_uuid;
    
    -- Migrate posts (if any posts exist without avatar_id)
    -- Note: Current schema already has avatar_id, but this handles legacy data
    UPDATE public.posts 
    SET avatar_id = avatar_uuid,
        updated_at = NOW()
    WHERE avatar_id IS NULL 
    AND EXISTS (
        SELECT 1 FROM public.avatars a 
        WHERE a.id = avatar_uuid AND a.owner_user_id = user_uuid
    );
    
    GET DIAGNOSTICS posts_migrated = ROW_COUNT;
    
    -- Note: Follows are already avatar-based in current schema
    -- This section would handle legacy user-to-user follows if they existed
    
    -- Log successful migration
    INSERT INTO migration_log (migration_type, status, details)
    VALUES (
        'user_migration',
        'completed',
        jsonb_build_object(
            'user_id', user_uuid,
            'avatar_id', avatar_uuid,
            'posts_migrated', posts_migrated,
            'follows_migrated', follows_migrated
        )
    );
    
    RETURN jsonb_build_object(
        'success', true,
        'user_id', user_uuid,
        'avatar_id', avatar_uuid,
        'posts_migrated', posts_migrated,
        'follows_migrated', follows_migrated
    );
    
EXCEPTION WHEN OTHERS THEN
    -- Log failed migration
    INSERT INTO migration_log (migration_type, status, error_message, details)
    VALUES (
        'user_migration',
        'failed',
        SQLERRM,
        jsonb_build_object('user_id', user_uuid)
    );
    
    RETURN jsonb_build_object(
        'success', false,
        'error', SQLERRM,
        'user_id', user_uuid
    );
END;
$$ LANGUAGE plpgsql;

-- Function to migrate all users
CREATE OR REPLACE FUNCTION migrate_all_users_to_avatar_centric()
RETURNS JSONB AS $$
DECLARE
    user_record RECORD;
    migration_result JSONB;
    total_users INTEGER := 0;
    successful_migrations INTEGER := 0;
    failed_migrations INTEGER := 0;
    results JSONB := '[]'::jsonb;
BEGIN
    -- Log migration start
    INSERT INTO migration_log (migration_type, status, details)
    VALUES ('bulk_migration', 'started', jsonb_build_object('started_at', NOW()));
    
    -- Get all users without active avatars
    FOR user_record IN 
        SELECT id, username FROM public.users 
        WHERE active_avatar_id IS NULL
        ORDER BY created_at ASC
    LOOP
        total_users := total_users + 1;
        
        -- Migrate individual user
        migration_result := migrate_user_to_avatar_centric(user_record.id);
        
        -- Track results
        IF migration_result->>'success' = 'true' THEN
            successful_migrations := successful_migrations + 1;
        ELSE
            failed_migrations := failed_migrations + 1;
        END IF;
        
        -- Add to results array
        results := results || jsonb_build_array(migration_result);
    END LOOP;
    
    -- Log migration completion
    INSERT INTO migration_log (migration_type, status, details)
    VALUES (
        'bulk_migration',
        CASE WHEN failed_migrations = 0 THEN 'completed' ELSE 'completed_with_errors' END,
        jsonb_build_object(
            'total_users', total_users,
            'successful_migrations', successful_migrations,
            'failed_migrations', failed_migrations,
            'completed_at', NOW()
        )
    );
    
    RETURN jsonb_build_object(
        'success', failed_migrations = 0,
        'total_users', total_users,
        'successful_migrations', successful_migrations,
        'failed_migrations', failed_migrations,
        'results', results
    );
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- ROLLBACK FUNCTIONS
-- ============================================================================

-- Function to rollback migration for a specific user
CREATE OR REPLACE FUNCTION rollback_user_migration(user_uuid UUID)
RETURNS JSONB AS $$
DECLARE
    migrated_avatar_id UUID;
BEGIN
    -- Get the migrated avatar ID
    SELECT active_avatar_id INTO migrated_avatar_id
    FROM public.users 
    WHERE id = user_uuid;
    
    -- Reset user's active avatar
    UPDATE public.users 
    SET active_avatar_id = NULL,
        updated_at = NOW()
    WHERE id = user_uuid;
    
    -- Delete the migrated avatar (if it was created during migration)
    DELETE FROM public.avatars 
    WHERE id = migrated_avatar_id 
    AND metadata->>'migrated_from_user' = 'true';
    
    -- Log rollback
    INSERT INTO migration_log (migration_type, status, details)
    VALUES (
        'user_rollback',
        'completed',
        jsonb_build_object(
            'user_id', user_uuid,
            'rolled_back_avatar_id', migrated_avatar_id
        )
    );
    
    RETURN jsonb_build_object(
        'success', true,
        'user_id', user_uuid,
        'rolled_back_avatar_id', migrated_avatar_id
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', SQLERRM,
        'user_id', user_uuid
    );
END;
$$ LANGUAGE plpgsql;

-- Function to rollback all migrations
CREATE OR REPLACE FUNCTION rollback_all_migrations()
RETURNS JSONB AS $$
DECLARE
    user_record RECORD;
    rollback_count INTEGER := 0;
BEGIN
    -- Log rollback start
    INSERT INTO migration_log (migration_type, status, details)
    VALUES ('bulk_rollback', 'started', jsonb_build_object('started_at', NOW()));
    
    -- Rollback all users with migrated avatars
    FOR user_record IN 
        SELECT u.id 
        FROM public.users u
        JOIN public.avatars a ON u.active_avatar_id = a.id
        WHERE a.metadata->>'migrated_from_user' = 'true'
    LOOP
        PERFORM rollback_user_migration(user_record.id);
        rollback_count := rollback_count + 1;
    END LOOP;
    
    -- Log rollback completion
    INSERT INTO migration_log (migration_type, status, details)
    VALUES (
        'bulk_rollback',
        'completed',
        jsonb_build_object(
            'users_rolled_back', rollback_count,
            'completed_at', NOW()
        )
    );
    
    RETURN jsonb_build_object(
        'success', true,
        'users_rolled_back', rollback_count
    );
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

-- Function to get migration statistics
CREATE OR REPLACE FUNCTION get_migration_statistics()
RETURNS JSONB AS $$
DECLARE
    total_users INTEGER;
    migrated_users INTEGER;
    total_avatars INTEGER;
    migrated_avatars INTEGER;
BEGIN
    -- Count total users
    SELECT COUNT(*) INTO total_users FROM public.users;
    
    -- Count migrated users (users with active avatars)
    SELECT COUNT(*) INTO migrated_users 
    FROM public.users 
    WHERE active_avatar_id IS NOT NULL;
    
    -- Count total avatars
    SELECT COUNT(*) INTO total_avatars FROM public.avatars;
    
    -- Count migrated avatars (avatars created during migration)
    SELECT COUNT(*) INTO migrated_avatars 
    FROM public.avatars 
    WHERE metadata->>'migrated_from_user' = 'true';
    
    RETURN jsonb_build_object(
        'total_users', total_users,
        'migrated_users', migrated_users,
        'users_needing_migration', total_users - migrated_users,
        'total_avatars', total_avatars,
        'migrated_avatars', migrated_avatars,
        'migration_completion_percentage', 
        CASE WHEN total_users > 0 
             THEN ROUND((migrated_users::DECIMAL / total_users) * 100, 2)
             ELSE 100 
        END
    );
END;
$$ LANGUAGE plpgsql;

-- Function to validate migration integrity
CREATE OR REPLACE FUNCTION validate_migration_integrity()
RETURNS JSONB AS $$
DECLARE
    issues JSONB := '[]'::jsonb;
    users_without_avatars INTEGER;
    avatars_without_owners INTEGER;
    posts_without_avatars INTEGER;
BEGIN
    -- Check for users without active avatars
    SELECT COUNT(*) INTO users_without_avatars
    FROM public.users 
    WHERE active_avatar_id IS NULL;
    
    IF users_without_avatars > 0 THEN
        issues := issues || jsonb_build_array(
            jsonb_build_object(
                'type', 'users_without_avatars',
                'count', users_without_avatars,
                'description', 'Users without active avatars'
            )
        );
    END IF;
    
    -- Check for avatars without valid owners
    SELECT COUNT(*) INTO avatars_without_owners
    FROM public.avatars a
    LEFT JOIN public.users u ON a.owner_user_id = u.id
    WHERE u.id IS NULL;
    
    IF avatars_without_owners > 0 THEN
        issues := issues || jsonb_build_array(
            jsonb_build_object(
                'type', 'avatars_without_owners',
                'count', avatars_without_owners,
                'description', 'Avatars with invalid owner references'
            )
        );
    END IF;
    
    -- Check for posts without avatar associations
    SELECT COUNT(*) INTO posts_without_avatars
    FROM public.posts 
    WHERE avatar_id IS NULL;
    
    IF posts_without_avatars > 0 THEN
        issues := issues || jsonb_build_array(
            jsonb_build_object(
                'type', 'posts_without_avatars',
                'count', posts_without_avatars,
                'description', 'Posts without avatar associations'
            )
        );
    END IF;
    
    RETURN jsonb_build_object(
        'valid', jsonb_array_length(issues) = 0,
        'issues', issues,
        'checked_at', NOW()
    );
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- EXAMPLE USAGE QUERIES
-- ============================================================================

-- Show migration statistics
-- SELECT get_migration_statistics();

-- Validate migration integrity
-- SELECT validate_migration_integrity();

-- Migrate all users (use with caution)
-- SELECT migrate_all_users_to_avatar_centric();

-- Migrate specific user
-- SELECT migrate_user_to_avatar_centric('user-uuid-here');

-- Rollback specific user
-- SELECT rollback_user_migration('user-uuid-here');

-- Rollback all migrations (use with extreme caution)
-- SELECT rollback_all_migrations();

-- View migration log
-- SELECT * FROM migration_log ORDER BY created_at DESC;

-- ============================================================================
-- CLEANUP (Run after successful migration)
-- ============================================================================

-- Drop backup tables (only after confirming migration success)
-- DROP TABLE IF EXISTS migration_backup_users;
-- DROP TABLE IF EXISTS migration_backup_avatars;
-- DROP TABLE IF EXISTS migration_backup_posts;
-- DROP TABLE IF EXISTS migration_backup_follows;

-- Drop migration functions (optional, keep for future use)
-- DROP FUNCTION IF EXISTS create_default_avatar_for_user(UUID, JSONB);
-- DROP FUNCTION IF EXISTS migrate_user_to_avatar_centric(UUID);
-- DROP FUNCTION IF EXISTS migrate_all_users_to_avatar_centric();
-- DROP FUNCTION IF EXISTS rollback_user_migration(UUID);
-- DROP FUNCTION IF EXISTS rollback_all_migrations();
-- DROP FUNCTION IF EXISTS get_migration_statistics();
-- DROP FUNCTION IF EXISTS validate_migration_integrity();
-- ===
=========================================================================
-- ADDITIONAL HELPER FUNCTIONS FOR MIGRATION VALIDATION
-- ============================================================================

-- Function to find orphaned avatars (for use with validator script)
CREATE OR REPLACE FUNCTION find_orphaned_avatars()
RETURNS TABLE(id UUID, name TEXT, owner_user_id UUID) AS $
BEGIN
    RETURN QUERY
    SELECT a.id, a.name, a.owner_user_id
    FROM public.avatars a
    LEFT JOIN public.users u ON a.owner_user_id = u.id
    WHERE u.id IS NULL;
END;
$ LANGUAGE plpgsql;

-- Function to find users with invalid avatar references
CREATE OR REPLACE FUNCTION find_invalid_avatar_refs()
RETURNS TABLE(id UUID, username TEXT, active_avatar_id UUID) AS $
BEGIN
    RETURN QUERY
    SELECT u.id, u.username, u.active_avatar_id
    FROM public.users u
    LEFT JOIN public.avatars a ON u.active_avatar_id = a.id
    WHERE u.active_avatar_id IS NOT NULL AND a.id IS NULL;
END;
$ LANGUAGE plpgsql;

-- Function to get detailed migration progress
CREATE OR REPLACE FUNCTION get_detailed_migration_progress()
RETURNS JSONB AS $
DECLARE
    result JSONB;
    total_users INTEGER;
    migrated_users INTEGER;
    users_with_avatars INTEGER;
    avatars_count INTEGER;
    posts_with_avatars INTEGER;
    posts_without_avatars INTEGER;
    follows_count INTEGER;
BEGIN
    -- Count users
    SELECT COUNT(*) INTO total_users FROM public.users;
    SELECT COUNT(*) INTO migrated_users FROM public.users WHERE active_avatar_id IS NOT NULL;
    
    -- Count avatars
    SELECT COUNT(*) INTO avatars_count FROM public.avatars;
    SELECT COUNT(*) INTO users_with_avatars 
    FROM public.users u 
    JOIN public.avatars a ON u.active_avatar_id = a.id;
    
    -- Count posts
    SELECT COUNT(*) INTO posts_with_avatars FROM public.posts WHERE avatar_id IS NOT NULL;
    SELECT COUNT(*) INTO posts_without_avatars FROM public.posts WHERE avatar_id IS NULL;
    
    -- Count follows
    SELECT COUNT(*) INTO follows_count FROM public.follows;
    
    result := jsonb_build_object(
        'users', jsonb_build_object(
            'total', total_users,
            'migrated', migrated_users,
            'with_valid_avatars', users_with_avatars,
            'migration_percentage', 
            CASE WHEN total_users > 0 
                 THEN ROUND((migrated_users::DECIMAL / total_users) * 100, 2)
                 ELSE 100 
            END
        ),
        'avatars', jsonb_build_object(
            'total', avatars_count,
            'migrated_from_users', (
                SELECT COUNT(*) FROM public.avatars 
                WHERE metadata->>'migrated_from_user' = 'true'
            )
        ),
        'posts', jsonb_build_object(
            'with_avatars', posts_with_avatars,
            'without_avatars', posts_without_avatars,
            'total', posts_with_avatars + posts_without_avatars
        ),
        'follows', jsonb_build_object(
            'total', follows_count,
            'with_valid_avatars', (
                SELECT COUNT(*) FROM public.follows f
                JOIN public.avatars a ON f.avatar_id = a.id
            )
        ),
        'generated_at', NOW()
    );
    
    RETURN result;
END;
$ LANGUAGE plpgsql;

-- Function to perform a dry run migration check
CREATE OR REPLACE FUNCTION dry_run_migration_check()
RETURNS JSONB AS $
DECLARE
    users_needing_migration INTEGER;
    potential_issues JSONB := '[]'::jsonb;
    issue JSONB;
BEGIN
    -- Count users needing migration
    SELECT COUNT(*) INTO users_needing_migration 
    FROM public.users 
    WHERE active_avatar_id IS NULL;
    
    -- Check for potential issues
    
    -- Issue 1: Users with duplicate usernames (could cause avatar name conflicts)
    IF EXISTS (
        SELECT username FROM public.users 
        WHERE username IS NOT NULL 
        GROUP BY username 
        HAVING COUNT(*) > 1
    ) THEN
        issue := jsonb_build_object(
            'type', 'duplicate_usernames',
            'severity', 'medium',
            'description', 'Users with duplicate usernames may cause avatar name conflicts',
            'count', (
                SELECT COUNT(*) FROM (
                    SELECT username FROM public.users 
                    WHERE username IS NOT NULL 
                    GROUP BY username 
                    HAVING COUNT(*) > 1
                ) AS duplicates
            )
        );
        potential_issues := potential_issues || jsonb_build_array(issue);
    END IF;
    
    -- Issue 2: Posts without any user association (orphaned posts)
    IF EXISTS (
        SELECT 1 FROM public.posts p
        LEFT JOIN public.avatars a ON p.avatar_id = a.id
        WHERE p.avatar_id IS NULL OR a.id IS NULL
    ) THEN
        issue := jsonb_build_object(
            'type', 'orphaned_posts',
            'severity', 'high',
            'description', 'Posts that cannot be associated with any avatar',
            'count', (
                SELECT COUNT(*) FROM public.posts p
                LEFT JOIN public.avatars a ON p.avatar_id = a.id
                WHERE p.avatar_id IS NULL OR a.id IS NULL
            )
        );
        potential_issues := potential_issues || jsonb_build_array(issue);
    END IF;
    
    -- Issue 3: Follows pointing to non-existent avatars
    IF EXISTS (
        SELECT 1 FROM public.follows f
        LEFT JOIN public.avatars a ON f.avatar_id = a.id
        WHERE a.id IS NULL
    ) THEN
        issue := jsonb_build_object(
            'type', 'invalid_follows',
            'severity', 'medium',
            'description', 'Follows pointing to non-existent avatars',
            'count', (
                SELECT COUNT(*) FROM public.follows f
                LEFT JOIN public.avatars a ON f.avatar_id = a.id
                WHERE a.id IS NULL
            )
        );
        potential_issues := potential_issues || jsonb_build_array(issue);
    END IF;
    
    RETURN jsonb_build_object(
        'users_needing_migration', users_needing_migration,
        'migration_required', users_needing_migration > 0,
        'potential_issues', potential_issues,
        'issues_count', jsonb_array_length(potential_issues),
        'ready_for_migration', jsonb_array_length(potential_issues) = 0,
        'checked_at', NOW()
    );
END;
$ LANGUAGE plpgsql;

-- ============================================================================
-- BATCH MIGRATION FUNCTIONS (for large datasets)
-- ============================================================================

-- Function to migrate users in batches
CREATE OR REPLACE FUNCTION migrate_users_batch(
    batch_size INTEGER DEFAULT 100,
    offset_value INTEGER DEFAULT 0
) RETURNS JSONB AS $
DECLARE
    user_record RECORD;
    migration_result JSONB;
    successful_count INTEGER := 0;
    failed_count INTEGER := 0;
    processed_count INTEGER := 0;
    results JSONB := '[]'::jsonb;
BEGIN
    -- Log batch start
    INSERT INTO migration_log (migration_type, status, details)
    VALUES (
        'batch_migration',
        'started',
        jsonb_build_object(
            'batch_size', batch_size,
            'offset', offset_value,
            'started_at', NOW()
        )
    );
    
    -- Process users in batch
    FOR user_record IN 
        SELECT id, username FROM public.users 
        WHERE active_avatar_id IS NULL
        ORDER BY created_at ASC
        LIMIT batch_size OFFSET offset_value
    LOOP
        processed_count := processed_count + 1;
        
        -- Migrate individual user
        migration_result := migrate_user_to_avatar_centric(user_record.id);
        
        -- Track results
        IF migration_result->>'success' = 'true' THEN
            successful_count := successful_count + 1;
        ELSE
            failed_count := failed_count + 1;
        END IF;
        
        -- Add to results (limit to prevent memory issues)
        IF processed_count <= 10 THEN
            results := results || jsonb_build_array(migration_result);
        END IF;
    END LOOP;
    
    -- Log batch completion
    INSERT INTO migration_log (migration_type, status, details)
    VALUES (
        'batch_migration',
        CASE WHEN failed_count = 0 THEN 'completed' ELSE 'completed_with_errors' END,
        jsonb_build_object(
            'batch_size', batch_size,
            'offset', offset_value,
            'processed_count', processed_count,
            'successful_count', successful_count,
            'failed_count', failed_count,
            'completed_at', NOW()
        )
    );
    
    RETURN jsonb_build_object(
        'success', failed_count = 0,
        'processed_count', processed_count,
        'successful_count', successful_count,
        'failed_count', failed_count,
        'has_more', processed_count = batch_size,
        'next_offset', offset_value + batch_size,
        'sample_results', results
    );
END;
$ LANGUAGE plpgsql;

-- ============================================================================
-- PERFORMANCE MONITORING FUNCTIONS
-- ============================================================================

-- Function to monitor migration performance
CREATE OR REPLACE FUNCTION get_migration_performance_stats()
RETURNS JSONB AS $
DECLARE
    stats JSONB;
    avg_migration_time INTERVAL;
    total_migrations INTEGER;
    recent_migrations INTEGER;
BEGIN
    -- Get migration statistics from log
    SELECT 
        COUNT(*) as total,
        COUNT(CASE WHEN created_at > NOW() - INTERVAL '1 hour' THEN 1 END) as recent,
        AVG(
            CASE 
                WHEN details ? 'completed_at' AND details ? 'started_at' 
                THEN (details->>'completed_at')::timestamp - (details->>'started_at')::timestamp
                ELSE NULL 
            END
        ) as avg_time
    INTO total_migrations, recent_migrations, avg_migration_time
    FROM migration_log
    WHERE migration_type = 'user_migration' AND status = 'completed';
    
    stats := jsonb_build_object(
        'total_migrations', COALESCE(total_migrations, 0),
        'recent_migrations_1h', COALESCE(recent_migrations, 0),
        'average_migration_time_seconds', 
        CASE 
            WHEN avg_migration_time IS NOT NULL 
            THEN EXTRACT(EPOCH FROM avg_migration_time)
            ELSE NULL 
        END,
        'migration_rate_per_hour', 
        CASE 
            WHEN recent_migrations > 0 
            THEN recent_migrations 
            ELSE 0 
        END,
        'database_stats', jsonb_build_object(
            'users_table_size', pg_size_pretty(pg_total_relation_size('public.users')),
            'avatars_table_size', pg_size_pretty(pg_total_relation_size('public.avatars')),
            'posts_table_size', pg_size_pretty(pg_total_relation_size('public.posts')),
            'follows_table_size', pg_size_pretty(pg_total_relation_size('public.follows'))
        ),
        'generated_at', NOW()
    );
    
    RETURN stats;
END;
$ LANGUAGE plpgsql;

-- ============================================================================
-- EXAMPLE BATCH MIGRATION USAGE
-- ============================================================================

-- Example: Migrate users in batches of 50
-- SELECT migrate_users_batch(50, 0);   -- First batch
-- SELECT migrate_users_batch(50, 50);  -- Second batch
-- SELECT migrate_users_batch(50, 100); -- Third batch

-- Example: Check if more batches are needed
-- SELECT 
--   CASE 
--     WHEN (result->>'has_more')::boolean 
--     THEN 'More batches needed. Next offset: ' || (result->>'next_offset')
--     ELSE 'All batches completed'
--   END as status
-- FROM (SELECT migrate_users_batch(50, 0) as result) as batch_result;

-- ============================================================================
-- MONITORING QUERIES
-- ============================================================================

-- Monitor migration progress in real-time
-- SELECT get_detailed_migration_progress();

-- Check migration performance
-- SELECT get_migration_performance_stats();

-- View recent migration activity
-- SELECT * FROM migration_log 
-- WHERE created_at > NOW() - INTERVAL '1 hour' 
-- ORDER BY created_at DESC;

-- Check for any failed migrations
-- SELECT * FROM migration_log 
-- WHERE status = 'failed' 
-- ORDER BY created_at DESC 
-- LIMIT 10;