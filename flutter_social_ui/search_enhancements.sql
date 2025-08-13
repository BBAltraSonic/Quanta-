-- Search Enhancement Tables and Functions
-- This script adds database support for:
-- 1. Popular searches tracking
-- 2. Recent searches persistence
-- 3. Enhanced error handling support

-- =============================================
-- SEARCH TRACKING TABLES
-- =============================================

-- Table to track search queries and their frequency
CREATE TABLE IF NOT EXISTS search_queries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    query TEXT NOT NULL,
    normalized_query TEXT NOT NULL, -- lowercase, trimmed version for deduplication
    search_count INTEGER DEFAULT 1,
    last_searched_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Index for fast lookups
CREATE INDEX IF NOT EXISTS idx_search_queries_normalized ON search_queries(normalized_query);
CREATE INDEX IF NOT EXISTS idx_search_queries_count ON search_queries(search_count DESC);
CREATE INDEX IF NOT EXISTS idx_search_queries_last_searched ON search_queries(last_searched_at DESC);

-- Table to track individual user's recent searches
CREATE TABLE IF NOT EXISTS user_recent_searches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    query TEXT NOT NULL,
    searched_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, query) -- Prevent duplicates
);

-- Index for fast user lookups
CREATE INDEX IF NOT EXISTS idx_user_recent_searches_user_id ON user_recent_searches(user_id, searched_at DESC);

-- =============================================
-- SEARCH TRACKING FUNCTIONS
-- =============================================

-- Function to track a search query (updates popular searches)
CREATE OR REPLACE FUNCTION track_search_query(search_query TEXT)
RETURNS VOID AS $$
DECLARE
    normalized TEXT;
BEGIN
    -- Normalize the query (lowercase, trim)
    normalized := TRIM(LOWER(search_query));
    
    -- Skip empty queries
    IF normalized = '' THEN
        RETURN;
    END IF;
    
    -- Insert or update search count
    INSERT INTO search_queries (query, normalized_query, search_count, last_searched_at, updated_at)
    VALUES (search_query, normalized, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    ON CONFLICT (normalized_query) DO UPDATE SET
        search_count = search_queries.search_count + 1,
        last_searched_at = CURRENT_TIMESTAMP,
        updated_at = CURRENT_TIMESTAMP,
        query = CASE 
            -- Keep the more recent capitalization
            WHEN search_queries.last_searched_at < CURRENT_TIMESTAMP THEN search_query
            ELSE search_queries.query
        END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get popular searches
CREATE OR REPLACE FUNCTION get_popular_searches(
    limit_count INTEGER DEFAULT 10,
    min_searches INTEGER DEFAULT 2
)
RETURNS TABLE (
    query TEXT,
    search_count INTEGER,
    last_searched_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        sq.query,
        sq.search_count,
        sq.last_searched_at
    FROM search_queries sq
    WHERE sq.search_count >= min_searches
    ORDER BY 
        sq.search_count DESC,
        sq.last_searched_at DESC
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to add a recent search for a user
CREATE OR REPLACE FUNCTION add_recent_search(
    p_user_id UUID,
    search_query TEXT
)
RETURNS VOID AS $$
DECLARE
    max_recent_searches INTEGER := 50; -- Keep only last 50 searches per user
BEGIN
    -- Skip empty queries
    IF TRIM(search_query) = '' THEN
        RETURN;
    END IF;
    
    -- Insert or update recent search (move to top if exists)
    INSERT INTO user_recent_searches (user_id, query, searched_at)
    VALUES (p_user_id, search_query, CURRENT_TIMESTAMP)
    ON CONFLICT (user_id, query) DO UPDATE SET
        searched_at = CURRENT_TIMESTAMP;
    
    -- Also track globally for popular searches
    PERFORM track_search_query(search_query);
    
    -- Clean up old searches to maintain limit
    DELETE FROM user_recent_searches 
    WHERE user_id = p_user_id 
    AND id NOT IN (
        SELECT id 
        FROM user_recent_searches 
        WHERE user_id = p_user_id 
        ORDER BY searched_at DESC 
        LIMIT max_recent_searches
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get user's recent searches
CREATE OR REPLACE FUNCTION get_recent_searches(
    p_user_id UUID,
    limit_count INTEGER DEFAULT 10
)
RETURNS TABLE (
    query TEXT,
    searched_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        urs.query,
        urs.searched_at
    FROM user_recent_searches urs
    WHERE urs.user_id = p_user_id
    ORDER BY urs.searched_at DESC
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to clear user's recent searches
CREATE OR REPLACE FUNCTION clear_recent_searches(p_user_id UUID)
RETURNS VOID AS $$
BEGIN
    DELETE FROM user_recent_searches WHERE user_id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to remove a specific recent search
CREATE OR REPLACE FUNCTION remove_recent_search(
    p_user_id UUID,
    search_query TEXT
)
RETURNS VOID AS $$
BEGIN
    DELETE FROM user_recent_searches 
    WHERE user_id = p_user_id AND query = search_query;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- ENABLE ROW LEVEL SECURITY
-- =============================================

-- Enable RLS on search tables
ALTER TABLE search_queries ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_recent_searches ENABLE ROW LEVEL SECURITY;

-- Policy for search_queries (public read, no direct writes)
CREATE POLICY "Allow read access to search queries" ON search_queries
    FOR SELECT USING (true);

-- Policy for user_recent_searches (users can only access their own)
CREATE POLICY "Users can view their own recent searches" ON user_recent_searches
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own recent searches" ON user_recent_searches
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own recent searches" ON user_recent_searches
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own recent searches" ON user_recent_searches
    FOR DELETE USING (auth.uid() = user_id);

-- =============================================
-- GRANT PERMISSIONS
-- =============================================

-- Grant necessary permissions
GRANT SELECT ON search_queries TO authenticated;
GRANT ALL ON user_recent_searches TO authenticated;

GRANT EXECUTE ON FUNCTION track_search_query(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_popular_searches(INTEGER, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION add_recent_search(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_recent_searches(UUID, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION clear_recent_searches(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION remove_recent_search(UUID, TEXT) TO authenticated;

-- =============================================
-- SAMPLE DATA FOR TESTING
-- =============================================

-- Add some sample popular searches
INSERT INTO search_queries (query, normalized_query, search_count, last_searched_at) 
VALUES 
    ('AI avatars', 'ai avatars', 25, CURRENT_TIMESTAMP - INTERVAL '1 day'),
    ('Technology', 'technology', 18, CURRENT_TIMESTAMP - INTERVAL '2 hours'),
    ('Fitness tips', 'fitness tips', 15, CURRENT_TIMESTAMP - INTERVAL '3 hours'),
    ('Travel', 'travel', 12, CURRENT_TIMESTAMP - INTERVAL '1 day'),
    ('Cooking recipes', 'cooking recipes', 10, CURRENT_TIMESTAMP - INTERVAL '5 hours'),
    ('Art inspiration', 'art inspiration', 8, CURRENT_TIMESTAMP - INTERVAL '6 hours'),
    ('Music production', 'music production', 7, CURRENT_TIMESTAMP - INTERVAL '1 day'),
    ('Gaming tips', 'gaming tips', 6, CURRENT_TIMESTAMP - INTERVAL '8 hours')
ON CONFLICT (normalized_query) DO NOTHING;

COMMIT;
