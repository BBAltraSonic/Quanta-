# Data Consistency Rules & Variable Naming Conventions

## Overview
This document establishes strict rules for data management to ensure a **single source of truth** across the entire Flutter application. Following these rules prevents variable duplication and ensures consistent data handling.

## 🚨 CRITICAL RULES - MUST FOLLOW

### Rule 1: Single Source of Truth
- **ALL** shared data MUST be stored in the central `AppState`
- **NO** local caching of data that exists in the central state
- **NO** duplicate variables for the same logical data

### Rule 2: Use StateServiceAdapter
- **ALL** screens and components MUST use `StateServiceAdapter` to access data
- **NO** direct instantiation of duplicate Lists, Maps, or Models
- **NO** local state for data that should be shared

### Rule 3: Consistent Naming Conventions
Follow these exact naming patterns:

#### Data Access (Read-Only)
```dart
// ✅ CORRECT - Use central state
final posts = _stateAdapter.feedPosts;
final user = _stateAdapter.currentUser;
final avatar = _stateAdapter.getAvatar(avatarId);
final isLiked = _stateAdapter.isPostLiked(postId);

// ❌ WRONG - Local variables for shared data
List<PostModel> _posts = [];
Map<String, bool> _likedStatus = {};
```

#### Data Modification
```dart
// ✅ CORRECT - Update through adapter
_stateAdapter.setPost(newPost);
_stateAdapter.optimisticTogglePostLike(postId);
_stateAdapter.setLoadingState('posts', true);

// ❌ WRONG - Local state modification
_posts.add(newPost);
_likedStatus[postId] = true;
```

#### Loading States
```dart
// ✅ CORRECT - Context-specific loading states
_stateAdapter.setLoadingState('feed_posts', true);
_stateAdapter.setLoadingState('user_profile', true);
_stateAdapter.getLoadingState('comments');

// ❌ WRONG - Generic or duplicate loading states
bool _isLoading = true;
bool _isPostsLoading = true;
bool _isProfileLoading = true;
```

### Rule 4: Data Model Usage
- Use `Comment` model from `lib/models/comment.dart` (NEVER use `CommentModel`)
- Use `PostModel` from `lib/models/post_model.dart`
- Use `UserModel` from `lib/models/user_model.dart`
- Use `AvatarModel` from `lib/models/avatar_model.dart`

## 📋 MANDATORY CHECKLIST FOR ALL NEW CODE

Before submitting ANY code, verify:

### ✅ Data Access Checklist
- [ ] No duplicate `List<PostModel>` variables
- [ ] No duplicate `Map<String, bool>` for likes/follows
- [ ] No duplicate `Map<String, AvatarModel>` caches
- [ ] All data accessed through `StateServiceAdapter`

### ✅ Variable Naming Checklist  
- [ ] Loading states use context-specific keys
- [ ] No generic variable names like `_posts`, `_comments`
- [ ] All getters reference central state
- [ ] No local caching of shared data

### ✅ State Management Checklist
- [ ] Updates go through `StateServiceAdapter` methods
- [ ] Optimistic updates use adapter convenience methods
- [ ] No direct manipulation of local collections
- [ ] Error handling reverts optimistic updates

## 🔧 REFACTORING PATTERNS

### Pattern 1: Replace Local Lists
```dart
// BEFORE ❌
class MyScreen extends StatefulWidget {
  List<PostModel> _posts = [];
  
  void _loadPosts() async {
    final posts = await service.getPosts();
    setState(() => _posts = posts);
  }
}

// AFTER ✅
class MyScreen extends StatefulWidget {
  final StateServiceAdapter _stateAdapter = StateServiceAdapter();
  
  List<PostModel> get _posts => _stateAdapter.feedPosts;
  
  void _loadPosts() async {
    _stateAdapter.setLoadingState('posts', true);
    final posts = await service.getPosts();
    _stateAdapter.setPosts(posts);
    _stateAdapter.setLoadingState('posts', false);
  }
}
```

### Pattern 2: Replace Local Status Maps
```dart
// BEFORE ❌
class MyScreen extends StatefulWidget {
  Map<String, bool> _likedStatus = {};
  
  void _toggleLike(String postId) {
    setState(() => _likedStatus[postId] = !_likedStatus[postId]);
  }
}

// AFTER ✅
class MyScreen extends StatefulWidget {
  final StateServiceAdapter _stateAdapter = StateServiceAdapter();
  
  bool _isPostLiked(String postId) => _stateAdapter.isPostLiked(postId);
  
  void _toggleLike(String postId) {
    _stateAdapter.optimisticTogglePostLike(postId);
  }
}
```

### Pattern 3: Replace Local Loading States
```dart
// BEFORE ❌
class MyScreen extends StatefulWidget {
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
}

// AFTER ✅
class MyScreen extends StatefulWidget {
  final StateServiceAdapter _stateAdapter = StateServiceAdapter();
  static const String _context = 'my_screen';
  
  bool get _isLoading => _stateAdapter.getLoadingState(_context);
  bool get _isLoadingMore => _stateAdapter.getLoadingState('${_context}_more');
  String? get _error => _stateAdapter.error;
}
```

## 🎯 CONTEXT NAMING CONVENTIONS

Use these specific contexts for loading states:

- `'feed'` - Main video feed
- `'profile'` - User profile data  
- `'comments'` - Post comments
- `'followers'` - User followers/following
- `'search'` - Search results
- `'upload'` - Content upload
- `'auth'` - Authentication

Append suffixes for specific operations:
- `'_more'` - Pagination loading (e.g., `'feed_more'`)
- `'_refresh'` - Pull-to-refresh (e.g., `'feed_refresh'`)

## 🚫 FORBIDDEN PATTERNS

### Never Do This:
```dart
// ❌ Local data caching
List<PostModel> _posts = [];
Map<String, AvatarModel> _avatarCache = {};
Map<String, UserModel> _userCache = {};
Map<String, bool> _likedStatus = {};
Map<String, bool> _followingStatus = {};

// ❌ Generic loading states  
bool _isLoading = true;
bool _hasError = false;
String _errorMessage = '';

// ❌ Duplicate comment models
import 'CommentModel' // Wrong model

// ❌ Direct state manipulation
_posts.add(newPost);
myList.clear();
myMap[key] = value;
```

### Always Do This Instead:
```dart
// ✅ Central state access
List<PostModel> get _posts => _stateAdapter.feedPosts;
AvatarModel? getAvatar(String id) => _stateAdapter.getAvatar(id);
bool get _isLoading => _stateAdapter.getLoadingState(_context);

// ✅ Central state updates
_stateAdapter.setPost(newPost);
_stateAdapter.clearAll();
_stateAdapter.setPostLikeStatus(id, isLiked);

// ✅ Correct model imports
import '../models/comment.dart'; // Unified Comment model
```

## 📝 CODE REVIEW REQUIREMENTS

All pull requests MUST pass these checks:

1. **Variable Duplication Check**: No duplicate variables for same data
2. **StateAdapter Usage Check**: All data access goes through adapter
3. **Naming Convention Check**: All variables follow naming patterns  
4. **Model Consistency Check**: Correct model imports used
5. **Central State Check**: No local state for shared data

### Automatic Checks
Run these searches before submitting:

```bash
# Check for forbidden patterns
grep -r "List<PostModel>" lib/ --exclude-dir=store --exclude-dir=models
grep -r "Map<String, bool>" lib/ --exclude-dir=store  
grep -r "_posts\s*=" lib/ --exclude-dir=store
grep -r "_likedStatus" lib/
grep -r "CommentModel" lib/ --exclude=post_model.dart
```

If any results are found (except in allowed directories), the code violates these rules.

## ⚡ PERFORMANCE BENEFITS

Following these rules provides:

- **Instant UI Updates**: Changes appear everywhere immediately
- **Reduced Memory Usage**: No duplicate data storage
- **Better Performance**: Single source eliminates sync overhead
- **Easier Debugging**: All state changes in one place
- **Consistent Behavior**: No race conditions between duplicates

## 🔄 MIGRATION STRATEGY

For existing code:

1. **Identify**: Find all duplicate variables using search patterns
2. **Replace**: Use `StateServiceAdapter` instead of local variables  
3. **Verify**: Ensure UI still updates reactively
4. **Test**: Confirm data consistency across screens
5. **Document**: Update any component-specific documentation

## 📚 EXAMPLES

See these files for correct implementation examples:

- `lib/screens/feeds_screen.dart` - Refactored to use central state
- `lib/store/app_state.dart` - Central state definition
- `lib/store/state_service_adapter.dart` - Adapter usage patterns

## ⚠️ ENFORCEMENT

These rules are **MANDATORY**. Violations will result in:

1. **Code Review Rejection**: PRs that violate rules will be rejected
2. **Refactoring Required**: Existing code must be updated  
3. **Architecture Reviews**: Major violations require team discussion

**Remember**: The goal is 95%+ confidence in data consistency. These rules ensure that updates in one place appear everywhere instantly.
