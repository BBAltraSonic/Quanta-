# Profile Screen Complete Implementation Specification

Based on the audit in `docs/profile_screen_audit.md` and analysis of the current implementation, this document provides a complete specification for the remaining unimplemented features.

## Current Status ✅
- **Phase 1**: Stats key fixes → ✅ COMPLETE  
- **Phase 2**: Active avatar and avatar-centric profile → ✅ COMPLETE
- **Phase 3**: Database-backed posts grid → ✅ COMPLETE
- **Phase 4**: Enhanced analytics → ✅ COMPLETE
- **Message/Chat CTA**: ✅ COMPLETE
- **Context-aware Follow button**: ✅ COMPLETE
- **Active avatar persistence**: ✅ COMPLETE

## Remaining Unimplemented Features

### Phase 5: PRD UX Alignment Features

#### 5.1 Pinned Post Section
**Purpose**: Display a featured post at the top of the posts grid to highlight the most important content.

**Inputs**:
- Avatar's pinned post ID (optional)
- Post data with enhanced thumbnail

**Outputs**:
- Prominent pinned post section above the masonry grid
- Clear visual distinction from regular posts

**Acceptance Criteria**:
- [ ] Add `pinned_post_id` column to `avatars` table
- [ ] Create pinned post UI component with enhanced styling
- [ ] Implement pinned post management in avatar settings
- [ ] Show "PIN" badge on pinned posts

**Constraints**:
- Only one pinned post per avatar
- Pinned post must be owned by the same avatar
- Graceful fallback when no pinned post exists

#### 5.2 Collaborations and Duets Tab/Section
**Purpose**: Showcase collaborative content to encourage community engagement.

**Inputs**:
- Posts with collaboration metadata
- Duet/remix relationships between posts
- Collaborating avatars information

**Outputs**:
- Horizontal scrollable section for collaborations
- Clear attribution to all collaborating avatars
- Easy navigation to collaborator profiles

**Acceptance Criteria**:
- [ ] Add `collaboration_metadata` JSONB field to `posts` table
- [ ] Create `post_collaborations` junction table
- [ ] Implement collaboration detection and display logic
- [ ] Add collaboration UI section to profile
- [ ] Support duet/remix relationship tracking

**Constraints**:
- Maximum 5 collaborators per post
- Must handle various collaboration types (duet, remix, collab)
- Performance optimized for loading collaborator data

### Phase 6: Robustness and Quality Improvements

#### 6.1 Enhanced Error Handling
**Purpose**: Provide graceful degradation and clear feedback for all error scenarios.

**Inputs**:
- Network failures
- Database errors
- Permission denied scenarios
- Missing data conditions

**Outputs**:
- User-friendly error messages
- Actionable recovery options
- Appropriate fallback content

**Acceptance Criteria**:
- [ ] Comprehensive error state components
- [ ] Retry mechanisms for transient failures
- [ ] Offline mode indicators
- [ ] Error boundary implementations
- [ ] Analytics for error tracking

#### 6.2 Performance Optimizations
**Purpose**: Ensure smooth performance across all devices and network conditions.

**Inputs**:
- Large datasets (posts, analytics, avatars)
- Various device capabilities
- Different network speeds

**Outputs**:
- Fast loading times (<2s for critical content)
- Smooth scrolling and animations
- Efficient memory usage

**Acceptance Criteria**:
- [ ] Implement proper pagination for all lists
- [ ] Add image lazy loading and caching
- [ ] Optimize database queries with proper indexing
- [ ] Implement skeleton loading states
- [ ] Bundle size optimization

#### 6.3 Accessibility Enhancements
**Purpose**: Ensure the profile screen is accessible to users with disabilities.

**Inputs**:
- Screen reader requirements
- Keyboard navigation needs
- Color contrast standards
- Touch target requirements

**Outputs**:
- WCAG 2.1 AA compliant interface
- Full keyboard navigation support
- Screen reader optimized experience

**Acceptance Criteria**:
- [ ] Add semantic HTML structure
- [ ] Implement proper ARIA labels
- [ ] Ensure color contrast ratios meet standards
- [ ] Add keyboard navigation support
- [ ] Test with screen readers

### Phase 7: Advanced Features

#### 7.1 Profile Customization
**Purpose**: Allow users to personalize their profile presentation.

**Inputs**:
- Theme preferences
- Layout options
- Featured content selections

**Outputs**:
- Customizable profile themes
- Flexible layout arrangements
- Personal branding options

**Acceptance Criteria**:
- [ ] Profile theme system
- [ ] Custom background options
- [ ] Layout customization UI
- [ ] Preview functionality
- [ ] Theme persistence

#### 7.2 Advanced Analytics Dashboard
**Purpose**: Provide deeper insights for content creators.

**Inputs**:
- Detailed engagement metrics
- Audience demographics
- Growth trends
- Performance comparisons

**Outputs**:
- Interactive analytics charts
- Exportable reports
- Actionable insights
- Benchmark comparisons

**Acceptance Criteria**:
- [ ] Advanced metrics calculation
- [ ] Interactive chart components
- [ ] Data export functionality
- [ ] Time-range filtering
- [ ] Performance benchmarking

## Implementation Tasks

### Database Schema Updates

#### Task 1: Add Pinned Post Support
```sql
-- Add pinned_post_id to avatars table
ALTER TABLE public.avatars 
ADD COLUMN pinned_post_id UUID REFERENCES public.posts(id);

-- Add index for performance
CREATE INDEX idx_avatars_pinned_post_id ON public.avatars(pinned_post_id);
```

#### Task 2: Add Collaboration Support
```sql
-- Add collaboration metadata to posts
ALTER TABLE public.posts 
ADD COLUMN collaboration_metadata JSONB DEFAULT '{}';

-- Create post collaborations junction table
CREATE TABLE public.post_collaborations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
    collaborator_avatar_id UUID NOT NULL REFERENCES public.avatars(id) ON DELETE CASCADE,
    collaboration_type TEXT NOT NULL CHECK (collaboration_type IN ('duet', 'remix', 'collab', 'mention')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(post_id, collaborator_avatar_id, collaboration_type)
);

-- Add indexes
CREATE INDEX idx_post_collaborations_post_id ON public.post_collaborations(post_id);
CREATE INDEX idx_post_collaborations_avatar_id ON public.post_collaborations(collaborator_avatar_id);

-- Enable RLS
ALTER TABLE public.post_collaborations ENABLE ROW LEVEL SECURITY;

-- Add RLS policies
CREATE POLICY "Users can view public collaborations" ON public.post_collaborations
    FOR SELECT USING (true);

CREATE POLICY "Users can manage their avatar collaborations" ON public.post_collaborations
    FOR ALL USING (
        collaborator_avatar_id IN (
            SELECT id FROM public.avatars WHERE owner_user_id = auth.uid()
        )
    );
```

### Service Layer Updates

#### Task 3: Enhanced Profile Service
```dart
// Add to ProfileService class

/// Get pinned post for an avatar
Future<PostModel?> getPinnedPost(String avatarId) async {
  try {
    final avatarResponse = await _authService.supabase
        .from('avatars')
        .select('pinned_post_id')
        .eq('id', avatarId)
        .single();
    
    final pinnedPostId = avatarResponse['pinned_post_id'] as String?;
    if (pinnedPostId == null) return null;
    
    final postResponse = await _authService.supabase
        .from('posts')
        .select('*')
        .eq('id', pinnedPostId)
        .eq('is_active', true)
        .single();
    
    return PostModel.fromJson(postResponse);
  } catch (e) {
    debugPrint('Error loading pinned post: $e');
    return null;
  }
}

/// Set pinned post for an avatar
Future<void> setPinnedPost(String avatarId, String? postId) async {
  try {
    await _authService.supabase
        .from('avatars')
        .update({'pinned_post_id': postId})
        .eq('id', avatarId);
  } catch (e) {
    throw Exception('Error setting pinned post: $e');
  }
}

/// Get collaborations for an avatar
Future<List<PostModel>> getCollaborationPosts(String avatarId, {int limit = 10}) async {
  try {
    final response = await _authService.supabase
        .from('post_collaborations')
        .select('''
          posts:post_id(
            *,
            avatar:avatar_id(id, name, avatar_image_url)
          )
        ''')
        .eq('collaborator_avatar_id', avatarId)
        .order('created_at', ascending: false)
        .limit(limit);
    
    return response
        .map((item) => PostModel.fromJson(item['posts']))
        .toList();
  } catch (e) {
    debugPrint('Error loading collaboration posts: $e');
    return [];
  }
}
```

### UI Component Updates

#### Task 4: Pinned Post Component
```dart
// Add to profile_screen.dart

Widget _buildPinnedPostSection() {
  if (_pinnedPost == null) return const SizedBox.shrink();
  
  return _HeaderCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.push_pin, color: kPrimaryColor, size: 18),
            const SizedBox(width: 8),
            const Text(
              'Pinned Post',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildEnhancedPostTile(
          post: _pinnedPost!,
          isPinned: true,
          height: 200,
          width: double.infinity,
        ),
      ],
    ),
  );
}

Widget _buildEnhancedPostTile({
  required PostModel post,
  bool isPinned = false,
  required double height,
  required double width,
}) {
  return GestureDetector(
    onTap: () => _navigateToPostDetail(post),
    child: Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(isPinned ? 16 : 12),
        boxShadow: isPinned ? [
          BoxShadow(
            color: kPrimaryColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ] : [],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Enhanced image display
          _buildPostImage(post),
          
          // Gradient overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withOpacity(0.7),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          
          // Enhanced content overlay
          _buildPostOverlay(post, isPinned),
        ],
      ),
    ),
  );
}
```

#### Task 5: Collaborations Section
```dart
// Add to profile_screen.dart

Widget _buildCollaborationsSection() {
  if (_collaborationPosts.isEmpty) return const SizedBox.shrink();
  
  return _HeaderCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.people, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Collaborations & Duets',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: _navigateToFullCollaborations,
              child: const Text(
                'View All',
                style: TextStyle(
                  color: kPrimaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _collaborationPosts.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final post = _collaborationPosts[index];
              return _buildCollaborationTile(post);
            },
          ),
        ),
      ],
    ),
  );
}

Widget _buildCollaborationTile(PostModel post) {
  return Container(
    width: 120,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      color: Colors.white.withOpacity(0.05),
      border: Border.all(color: Colors.orange.withOpacity(0.3)),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        // Thumbnail
        Expanded(
          flex: 3,
          child: Container(
            width: double.infinity,
            child: _buildPostImage(post),
          ),
        ),
        // Collaboration info
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'with ${_getCollaboratorNames(post)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _getCollaborationType(post),
                    style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
```

### Testing Strategy

#### Unit Tests
- [ ] ProfileService methods for pinned posts
- [ ] ProfileService methods for collaborations  
- [ ] UI widget tests for new components
- [ ] Data model validation tests

#### Integration Tests
- [ ] End-to-end profile loading with all features
- [ ] Pinned post management flow
- [ ] Collaboration display and navigation
- [ ] Error handling scenarios

#### Performance Tests
- [ ] Profile loading time benchmarks
- [ ] Memory usage profiling
- [ ] Large dataset handling
- [ ] Network failure recovery

## Acceptance Criteria Summary

### Phase 5 Completion Criteria
- [ ] Pinned post functionality working end-to-end
- [ ] Collaborations section displays relevant content
- [ ] All database migrations applied successfully
- [ ] UI components match design specifications
- [ ] Performance meets established benchmarks

### Phase 6 Completion Criteria  
- [ ] Error handling covers all identified scenarios
- [ ] Accessibility audit passes with no critical issues
- [ ] Performance testing shows <2s load times
- [ ] Code coverage >80% for new functionality

### Phase 7 Completion Criteria
- [ ] Profile customization features fully functional
- [ ] Advanced analytics provide actionable insights
- [ ] All features documented and tested
- [ ] User acceptance testing completed successfully

## Timeline Estimates

- **Phase 5**: 5-7 days (with pinned posts and collaborations)
- **Phase 6**: 8-10 days (comprehensive robustness improvements)
- **Phase 7**: 10-14 days (advanced features)

**Total estimated time**: 23-31 days for complete implementation

## Dependencies and Risks

### Technical Dependencies
- Database migration coordination with production
- Asset management for enhanced thumbnails
- Third-party analytics service integration

### Risks and Mitigations
- **Performance impact**: Implement progressive loading and caching
- **Database migration complexity**: Use feature flags and rollback plans
- **UI consistency**: Maintain comprehensive design system
- **Testing coverage**: Implement automated testing pipeline

## Success Metrics

- Profile load time < 2 seconds
- User engagement with pinned posts > 15%
- Collaboration discovery rate > 10%
- Error rate < 0.5%
- Accessibility score > 95%
- User satisfaction rating > 4.5/5
