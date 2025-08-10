# Mock, Demo, and Fake Artifacts Inventory

## Executive Summary
- **Total Demo Services Found**: 3 major demo services with wrapper pattern
- **Configuration-Based Switching**: AppConfig.demoMode controls demo vs production
- **Impact Level**: HIGH - Entire app can run in demo mode
- **Priority**: CRITICAL - All demo services must be removed

## Demo Services (CRITICAL - Core Infrastructure)

### 1. Demo Authentication Service
**File**: `lib/services/demo_auth_service.dart`
- **Size**: 209 lines
- **Purpose**: Complete demo authentication without Supabase
- **Dependencies**: SharedPreferences for local storage
- **Features**: Sign up, sign in, sign out, password reset, profile updates
- **Storage**: Persists demo user data in local storage with `demo_` prefixes
- **Status**: ❌ ACTIVE - Referenced in main.dart via wrapper

### 2. Demo Content Service  
**File**: `lib/services/demo_content_service.dart`
- **Size**: 304 lines
- **Purpose**: Demo content management without Supabase
- **Features**: Create posts, get feed, comments, engagement tracking
- **Demo Data**: Generates hardcoded demo posts with fake URLs
- **Hashtags**: Uses demo hashtags like #demo, #ai, #avatar
- **Status**: ❌ ACTIVE - Referenced via wrapper

### 3. Demo Search Service
**File**: `lib/services/demo_search_service.dart`
- **Size**: 172 lines
- **Purpose**: Demo search functionality
- **Features**: Search posts, hashtags, avatars, trending searches
- **Demo Data**: Returns hardcoded demo search results
- **Status**: ❌ ACTIVE - Referenced via wrapper

## Service Wrappers (CRITICAL - Runtime Switching)

### 1. Auth Service Wrapper
**File**: `lib/services/auth_service_wrapper.dart`
- **Lines with demo logic**: 4, 7, 24, 91
- **Switching logic**: `AppConfig.demoMode` determines service selection
- **Impact**: Main entry point for all authentication
- **Status**: ❌ ACTIVE - Used in main.dart initialization

### 2. Content Service Wrapper
**File**: `lib/services/content_service_wrapper.dart`
- **Lines with demo logic**: 4, 8, 26
- **Switching logic**: `AppConfig.demoMode` determines service selection
- **Impact**: Main entry point for all content operations
- **Status**: ❌ ACTIVE

### 3. Search Service Wrapper  
**File**: `lib/services/search_service_wrapper.dart`
- **Lines with demo logic**: Multiple throughout
- **Status**: ❌ ACTIVE

## Configuration (HIGH PRIORITY)

### App Configuration
**File**: `lib/config/app_config.dart`
- **Demo mode flag**: Line 23 `static const bool demoMode = isDevelopment;`
- **Feature flags**: Lines 27, 34 have demo fallbacks
- **Production check**: Lines 26-31 bypass validation in demo mode
- **Impact**: Controls entire app behavior
- **Status**: ❌ ACTIVE - Currently enabled in development

## Assets and Placeholders (MEDIUM PRIORITY)

### Icon Placeholders
**File**: `assets/icons/icons_placeholders.svgpack.json`
- **Purpose**: Placeholder icon definitions
- **Status**: ❌ PRESENT - Should be replaced with real icons

**File**: `assets/icons/placeholder_icons_readme.txt`  
- **Purpose**: Documentation for placeholder icons
- **Status**: ❌ PRESENT - Should be removed

## Demo Content in Code (LOW-MEDIUM PRIORITY)

### Hardcoded Demo URLs
- Demo video URLs: `https://demo.video.url`
- Demo image URLs: `https://demo.image.url`  
- Demo thumbnail URLs: `https://demo.thumbnail.url`
- Demo avatar URLs: `https://demo.avatar.url`

### Demo User Data
- Demo user IDs: `demo-user-1`, `demo-user-2`, etc.
- Demo avatar IDs: `demo-avatar-id`, `demo-avatar-1`, etc.  
- Demo owner IDs: `demo-owner-id`

### Demo Hashtags
- `#demo`, `#ai`, `#avatar`, `#sample`, `#placeholder`

### Demo Text Content
- "This is a demo post in the Quanta AI Avatar Platform!"
- "Welcome to Quanta! 🚀 This is a demo post showcasing..."
- Multiple instances of "Demo User", "Demo Avatar"

## Services with Demo Fallbacks

### Other Services with Demo References
1. `lib/services/follow_service.dart` - Lines 21, 221, 224, 232, 241, 244, 273, 481-488
2. `lib/services/comment_service.dart` - Lines 20, 127, 162, 167, 199, 313-347
3. `lib/services/notification_service_enhanced.dart` - Lines 15, 290-358
4. `lib/services/content_upload_service.dart` - Lines 277, 279, 280, 319

## SharedPreferences Demo Keys
- `demo_user_email`
- `demo_user_username` 
- `demo_user_display_name`
- `demo_onboarding_completed`

## Documentation with Demo References
- Multiple .md files contain demo references (SPEC.md, CHECKLIST.md, etc.)
- These are planning documents and can remain

## Risk Assessment
- **HIGH RISK**: Demo services are fully functional and could ship to production
- **MEDIUM RISK**: Feature flags could accidentally enable demo mode in production
- **LOW RISK**: Asset placeholders are visible but won't break functionality

## Next Actions Required
1. Remove all demo service files
2. Remove all service wrappers  
3. Update AppConfig to remove demo mode
4. Update main.dart to use production services directly
5. Remove demo-related SharedPreferences keys
6. Replace placeholder assets
7. Scan for and remove all demo content/URLs
