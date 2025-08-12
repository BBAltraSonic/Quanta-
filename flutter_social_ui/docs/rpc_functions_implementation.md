# RPC Functions Implementation

This document describes the implementation of secure, RLS-safe RPC functions for view and like counters in the Quanta platform.

## Overview

The RPC functions provide atomic, secure operations for updating post interaction counters with proper authentication, authorization, and error handling.

## Functions Implemented

### 1. `increment_view_count(target_post_id UUID)`

**Purpose**: Safely increments the view count for a post.

**Security Features**:
- Requires user authentication
- Uses `SECURITY DEFINER` for RLS bypass
- Validates post existence and active status
- Atomic operation with proper error handling

**Parameters**:
- `target_post_id`: UUID of the post to increment views for

**Returns**: JSON object with success status and updated view count

**Example Usage**:
```dart
final result = await supabase.rpc('increment_view_count', params: {
  'target_post_id': postId,
});

if (result['success']) {
  final viewCount = result['data']['views_count'];
  print('Updated view count: $viewCount');
}
```

### 2. `increment_likes_count(target_post_id UUID)`

**Purpose**: Safely increments the likes count for a post and creates a like record.

**Security Features**:
- Requires user authentication
- Uses `SECURITY DEFINER` for RLS bypass
- Prevents duplicate likes from same user
- Validates post existence and active status
- Atomic operation with proper error handling

**Parameters**:
- `target_post_id`: UUID of the post to like

**Returns**: JSON object with success status, updated like count, and user like status

**Example Usage**:
```dart
final result = await supabase.rpc('increment_likes_count', params: {
  'target_post_id': postId,
});

if (result['success']) {
  final likeCount = result['data']['likes_count'];
  final userLiked = result['data']['user_liked'];
  print('Updated like count: $likeCount, User liked: $userLiked');
}
```

### 3. `decrement_likes_count(target_post_id UUID)`

**Purpose**: Safely decrements the likes count for a post and removes the like record.

**Security Features**:
- Requires user authentication
- Uses `SECURITY DEFINER` for RLS bypass
- Only allows unliking previously liked posts
- Validates post existence and active status
- Atomic operation with proper error handling

**Parameters**:
- `target_post_id`: UUID of the post to unlike

**Returns**: JSON object with success status, updated like count, and user like status

**Example Usage**:
```dart
final result = await supabase.rpc('decrement_likes_count', params: {
  'target_post_id': postId,
});

if (result['success']) {
  final likeCount = result['data']['likes_count'];
  final userLiked = result['data']['user_liked'];
  print('Updated like count: $likeCount, User liked: $userLiked');
}
```

### 4. `get_post_interaction_status(target_post_id UUID)`

**Purpose**: Retrieves the current interaction status of a post for the authenticated user.

**Security Features**:
- Requires user authentication
- Uses `SECURITY DEFINER` for RLS bypass
- Validates post existence and active status

**Parameters**:
- `target_post_id`: UUID of the post to get status for

**Returns**: JSON object with post interaction data including counters and user like status

**Example Usage**:
```dart
final result = await supabase.rpc('get_post_interaction_status', params: {
  'target_post_id': postId,
});

if (result['success']) {
  final data = result['data'];
  print('Views: ${data['views_count']}');
  print('Likes: ${data['likes_count']}');
  print('Comments: ${data['comments_count']}');
  print('User liked: ${data['user_liked']}');
}
```

## Error Handling

All functions return a consistent JSON structure:

**Success Response**:
```json
{
  "success": true,
  "data": {
    "post_id": "uuid",
    "views_count": 123,
    "likes_count": 45,
    "user_liked": true
  }
}
```

**Error Response**:
```json
{
  "success": false,
  "error": "Error message",
  "code": "ERROR_CODE"
}
```

### Error Codes

- `AUTH_REQUIRED`: User authentication is required
- `POST_NOT_FOUND`: Post doesn't exist or is inactive
- `ALREADY_LIKED`: User has already liked this post
- `NOT_LIKED`: User hasn't liked this post (for unlike operations)
- `UPDATE_FAILED`: Database operation failed
- `QUERY_FAILED`: Query execution failed

## Security Considerations

1. **Authentication**: All functions require user authentication via `auth.uid()`
2. **Authorization**: Functions use `SECURITY DEFINER` to bypass RLS for system operations
3. **Input Validation**: All inputs are validated before processing
4. **Atomic Operations**: All database operations are atomic to prevent race conditions
5. **Error Handling**: Comprehensive error handling prevents information leakage

## Database Schema Requirements

The functions require the following database structure:

```sql
-- Posts table with counter columns
CREATE TABLE public.posts (
    id UUID PRIMARY KEY,
    avatar_id UUID REFERENCES public.avatars(id),
    views_count INTEGER DEFAULT 0,
    likes_count INTEGER DEFAULT 0,
    comments_count INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    -- ... other columns
);

-- Likes table for tracking user likes
CREATE TABLE public.likes (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id),
    post_id UUID REFERENCES public.posts(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, post_id)
);
```

## Integration Tests

Comprehensive integration tests are provided in `test/integration/rpc_functions_test.dart` covering:

1. **Functionality Tests**:
   - View count increment
   - Like count increment/decrement
   - Interaction status retrieval

2. **Security Tests**:
   - Authentication requirements
   - Authorization checks
   - Input validation

3. **Error Handling Tests**:
   - Invalid post IDs
   - Duplicate operations
   - Unauthenticated access

4. **Integration Flow Tests**:
   - Complete like/unlike workflows
   - Multiple view increments
   - State consistency

### Running Tests

Use the provided test runner script:

```bash
./test_rpc_functions.sh
```

Or run directly with Flutter:

```bash
flutter test test/integration/rpc_functions_test.dart
```

## Deployment

1. **Deploy Functions**: Execute `database_rpc_functions.sql` in your Supabase database
2. **Verify Permissions**: Ensure functions have proper execution permissions
3. **Run Tests**: Execute integration tests to verify functionality
4. **Update Client Code**: Use the functions in your Flutter application

## Performance Considerations

1. **Indexes**: Ensure proper indexes exist on frequently queried columns
2. **Connection Pooling**: Use connection pooling for high-traffic applications
3. **Caching**: Consider caching frequently accessed data
4. **Monitoring**: Monitor function execution times and error rates

## Migration from Previous Implementation

If you have existing counter update logic:

1. Deploy the new RPC functions
2. Update client code to use RPC functions instead of direct table updates
3. Test thoroughly in development environment
4. Deploy to production with monitoring
5. Remove old counter update logic after verification

## Troubleshooting

### Common Issues

1. **Permission Denied**: Ensure user is authenticated and functions have proper grants
2. **Function Not Found**: Verify functions were deployed correctly to database
3. **RLS Violations**: Functions use SECURITY DEFINER to bypass RLS
4. **Unique Constraint Violations**: Functions handle duplicate likes gracefully

### Debugging

Enable detailed logging in your application to track function calls and responses:

```dart
final result = await supabase.rpc('increment_likes_count', params: {
  'target_post_id': postId,
});

print('RPC Result: $result');

if (!result['success']) {
  print('Error: ${result['error']} (${result['code']})');
}
```
