import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/avatar_model.dart';
import '../models/post_model.dart';

/// Service for optimized database queries for avatar operations
class AvatarDatabaseOptimizationService {
  static final AvatarDatabaseOptimizationService _instance =
      AvatarDatabaseOptimizationService._internal();
  factory AvatarDatabaseOptimizationService() => _instance;
  AvatarDatabaseOptimizationService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  /// Optimized query to get avatar profile with stats in a single request
  Future<Map<String, dynamic>> getAvatarProfileOptimized(
    String avatarId,
  ) async {
    final response = await _supabase.rpc(
      'get_avatar_profile_optimized',
      params: {'avatar_id_param': avatarId},
    );

    return response as Map<String, dynamic>;
  }

  /// Optimized query to get multiple avatars with stats
  Future<List<Map<String, dynamic>>> getMultipleAvatarsOptimized(
    List<String> avatarIds,
  ) async {
    if (avatarIds.isEmpty) return [];

    final response = await _supabase.rpc(
      'get_multiple_avatars_optimized',
      params: {'avatar_ids_param': avatarIds},
    );

    return List<Map<String, dynamic>>.from(response as List);
  }

  /// Optimized query to get user's avatars with stats
  Future<List<Map<String, dynamic>>> getUserAvatarsOptimized(
    String userId,
  ) async {
    final response = await _supabase.rpc(
      'get_user_avatars_optimized',
      params: {'user_id_param': userId},
    );

    return List<Map<String, dynamic>>.from(response as List);
  }

  /// Optimized query to get avatar posts with pagination and stats
  Future<Map<String, dynamic>> getAvatarPostsOptimized(
    String avatarId, {
    int offset = 0,
    int limit = 20,
  }) async {
    final response = await _supabase.rpc(
      'get_avatar_posts_optimized',
      params: {
        'avatar_id_param': avatarId,
        'offset_param': offset,
        'limit_param': limit,
      },
    );

    return response as Map<String, dynamic>;
  }

  /// Optimized query to get trending avatars
  Future<List<Map<String, dynamic>>> getTrendingAvatarsOptimized({
    int limit = 10,
    String timeframe = '7d', // 1d, 7d, 30d
  }) async {
    final response = await _supabase.rpc(
      'get_trending_avatars_optimized',
      params: {'limit_param': limit, 'timeframe_param': timeframe},
    );

    return List<Map<String, dynamic>>.from(response as List);
  }

  /// Optimized query to search avatars with full-text search
  Future<List<Map<String, dynamic>>> searchAvatarsOptimized(
    String query, {
    int offset = 0,
    int limit = 20,
  }) async {
    final response = await _supabase.rpc(
      'search_avatars_optimized',
      params: {
        'search_query': query,
        'offset_param': offset,
        'limit_param': limit,
      },
    );

    return List<Map<String, dynamic>>.from(response as List);
  }

  /// Optimized query to get avatar engagement metrics
  Future<Map<String, dynamic>> getAvatarEngagementMetrics(
    String avatarId, {
    String timeframe = '30d',
  }) async {
    final response = await _supabase.rpc(
      'get_avatar_engagement_metrics',
      params: {'avatar_id_param': avatarId, 'timeframe_param': timeframe},
    );

    return response as Map<String, dynamic>;
  }

  /// Batch update avatar stats (for performance)
  Future<void> batchUpdateAvatarStats(
    List<Map<String, dynamic>> updates,
  ) async {
    if (updates.isEmpty) return;

    await _supabase.rpc(
      'batch_update_avatar_stats',
      params: {'updates_param': updates},
    );
  }

  /// Get database performance metrics
  Future<Map<String, dynamic>> getDatabasePerformanceMetrics() async {
    final response = await _supabase.rpc('get_avatar_db_performance_metrics');
    return response as Map<String, dynamic>;
  }

  /// Create optimized database indexes (admin function)
  Future<void> createOptimizedIndexes() async {
    await _supabase.rpc('create_avatar_optimized_indexes');
  }

  /// Analyze query performance for avatar operations
  Future<Map<String, dynamic>> analyzeQueryPerformance(String operation) async {
    final response = await _supabase.rpc(
      'analyze_avatar_query_performance',
      params: {'operation_param': operation},
    );

    return response as Map<String, dynamic>;
  }
}

/// SQL functions that should be created in the database for optimization
/// These would be deployed as part of the database migration
class AvatarDatabaseFunctions {
  static const String createOptimizedFunctions = '''
-- Function to get avatar profile with stats in a single query
CREATE OR REPLACE FUNCTION get_avatar_profile_optimized(avatar_id_param UUID)
RETURNS JSON AS \$\$
DECLARE
  result JSON;
BEGIN
  SELECT json_build_object(
    'avatar', row_to_json(a.*),
    'stats', json_build_object(
      'followers_count', COALESCE(f.followers_count, 0),
      'posts_count', COALESCE(p.posts_count, 0),
      'total_likes', COALESCE(p.total_likes, 0),
      'engagement_rate', COALESCE(p.engagement_rate, 0.0)
    )
  ) INTO result
  FROM avatars a
  LEFT JOIN (
    SELECT 
      avatar_id,
      COUNT(*) as followers_count
    FROM follows 
    WHERE avatar_id = avatar_id_param
    GROUP BY avatar_id
  ) f ON a.id = f.avatar_id
  LEFT JOIN (
    SELECT 
      avatar_id,
      COUNT(*) as posts_count,
      SUM(likes_count) as total_likes,
      AVG(CASE WHEN views_count > 0 THEN (likes_count + comments_count)::float / views_count ELSE 0 END) as engagement_rate
    FROM posts 
    WHERE avatar_id = avatar_id_param
    GROUP BY avatar_id
  ) p ON a.id = p.avatar_id
  WHERE a.id = avatar_id_param;
  
  RETURN result;
END;
\$\$ LANGUAGE plpgsql;

-- Function to get multiple avatars with stats
CREATE OR REPLACE FUNCTION get_multiple_avatars_optimized(avatar_ids_param UUID[])
RETURNS JSON AS \$\$
BEGIN
  RETURN (
    SELECT json_agg(
      json_build_object(
        'avatar', row_to_json(a.*),
        'stats', json_build_object(
          'followers_count', COALESCE(f.followers_count, 0),
          'posts_count', COALESCE(p.posts_count, 0),
          'total_likes', COALESCE(p.total_likes, 0)
        )
      )
    )
    FROM avatars a
    LEFT JOIN (
      SELECT 
        avatar_id,
        COUNT(*) as followers_count
      FROM follows 
      WHERE avatar_id = ANY(avatar_ids_param)
      GROUP BY avatar_id
    ) f ON a.id = f.avatar_id
    LEFT JOIN (
      SELECT 
        avatar_id,
        COUNT(*) as posts_count,
        SUM(likes_count) as total_likes
      FROM posts 
      WHERE avatar_id = ANY(avatar_ids_param)
      GROUP BY avatar_id
    ) p ON a.id = p.avatar_id
    WHERE a.id = ANY(avatar_ids_param)
  );
END;
\$\$ LANGUAGE plpgsql;

-- Function to get user avatars with stats
CREATE OR REPLACE FUNCTION get_user_avatars_optimized(user_id_param UUID)
RETURNS JSON AS \$\$
BEGIN
  RETURN (
    SELECT json_agg(
      json_build_object(
        'avatar', row_to_json(a.*),
        'stats', json_build_object(
          'followers_count', COALESCE(f.followers_count, 0),
          'posts_count', COALESCE(p.posts_count, 0),
          'total_likes', COALESCE(p.total_likes, 0)
        )
      )
    )
    FROM avatars a
    LEFT JOIN (
      SELECT 
        avatar_id,
        COUNT(*) as followers_count
      FROM follows 
      GROUP BY avatar_id
    ) f ON a.id = f.avatar_id
    LEFT JOIN (
      SELECT 
        avatar_id,
        COUNT(*) as posts_count,
        SUM(likes_count) as total_likes
      FROM posts 
      GROUP BY avatar_id
    ) p ON a.id = p.avatar_id
    WHERE a.owner_user_id = user_id_param
    ORDER BY a.created_at DESC
  );
END;
\$\$ LANGUAGE plpgsql;

-- Function to get avatar posts with pagination
CREATE OR REPLACE FUNCTION get_avatar_posts_optimized(
  avatar_id_param UUID,
  offset_param INT DEFAULT 0,
  limit_param INT DEFAULT 20
)
RETURNS JSON AS \$\$
BEGIN
  RETURN json_build_object(
    'posts', (
      SELECT json_agg(row_to_json(p.*))
      FROM posts p
      WHERE p.avatar_id = avatar_id_param
      ORDER BY p.created_at DESC
      LIMIT limit_param OFFSET offset_param
    ),
    'total_count', (
      SELECT COUNT(*)
      FROM posts
      WHERE avatar_id = avatar_id_param
    ),
    'has_more', (
      SELECT COUNT(*) > (offset_param + limit_param)
      FROM posts
      WHERE avatar_id = avatar_id_param
    )
  );
END;
\$\$ LANGUAGE plpgsql;

-- Function to get trending avatars
CREATE OR REPLACE FUNCTION get_trending_avatars_optimized(
  limit_param INT DEFAULT 10,
  timeframe_param TEXT DEFAULT '7d'
)
RETURNS JSON AS \$\$
DECLARE
  time_filter TIMESTAMP;
BEGIN
  -- Calculate time filter based on timeframe
  CASE timeframe_param
    WHEN '1d' THEN time_filter := NOW() - INTERVAL '1 day';
    WHEN '7d' THEN time_filter := NOW() - INTERVAL '7 days';
    WHEN '30d' THEN time_filter := NOW() - INTERVAL '30 days';
    ELSE time_filter := NOW() - INTERVAL '7 days';
  END CASE;

  RETURN (
    SELECT json_agg(
      json_build_object(
        'avatar', row_to_json(a.*),
        'trending_score', t.trending_score,
        'stats', json_build_object(
          'followers_count', COALESCE(f.followers_count, 0),
          'recent_posts', COALESCE(t.recent_posts, 0),
          'recent_engagement', COALESCE(t.recent_engagement, 0)
        )
      )
    )
    FROM avatars a
    INNER JOIN (
      SELECT 
        avatar_id,
        COUNT(*) as recent_posts,
        SUM(likes_count + comments_count + shares_count) as recent_engagement,
        (COUNT(*) * 0.3 + SUM(likes_count + comments_count + shares_count) * 0.7) as trending_score
      FROM posts
      WHERE created_at >= time_filter
      GROUP BY avatar_id
      HAVING COUNT(*) > 0
      ORDER BY trending_score DESC
      LIMIT limit_param
    ) t ON a.id = t.avatar_id
    LEFT JOIN (
      SELECT 
        avatar_id,
        COUNT(*) as followers_count
      FROM follows 
      GROUP BY avatar_id
    ) f ON a.id = f.avatar_id
    ORDER BY t.trending_score DESC
  );
END;
\$\$ LANGUAGE plpgsql;

-- Create optimized indexes
CREATE OR REPLACE FUNCTION create_avatar_optimized_indexes()
RETURNS VOID AS \$\$
BEGIN
  -- Avatar indexes
  CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_avatars_owner_user_id ON avatars(owner_user_id);
  CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_avatars_created_at ON avatars(created_at DESC);
  CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_avatars_name_trgm ON avatars USING gin(name gin_trgm_ops);
  
  -- Posts indexes for avatar queries
  CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_posts_avatar_id_created_at ON posts(avatar_id, created_at DESC);
  CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_posts_avatar_id_likes ON posts(avatar_id, likes_count DESC);
  
  -- Follows indexes for avatar stats
  CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_follows_avatar_id ON follows(avatar_id);
  CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_follows_user_avatar ON follows(user_id, avatar_id);
  
  -- Composite indexes for performance
  CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_posts_trending ON posts(created_at DESC, likes_count DESC, comments_count DESC) 
    WHERE created_at >= NOW() - INTERVAL '30 days';
END;
\$\$ LANGUAGE plpgsql;
''';
}
