# Remove Demo Mode - Production Mode Specification

## Purpose
Remove all demo mode functionality, mock data, and placeholders from the Flutter social UI app to make it production-ready with real Supabase integration.

## Inputs
- Current Flutter app with demo mode system
- Environment configuration in `app_config.dart`
- Demo service implementations (`demo_auth_service.dart`, `demo_content_service.dart`, `demo_search_service.dart`)
- Service wrapper classes that switch between demo and production modes
- Placeholder assets and mock data throughout the app

## Outputs
- Production-ready app with no demo mode
- All services directly using Supabase/production implementations
- Removed demo services and wrapper logic
- Updated configuration to production mode
- Cleaned placeholder assets and mock data references

## Acceptance Criteria
1. **Configuration Changes**:
   - Remove `Environment.demo` from enum
   - Remove `isDemoMode` property and related checks
   - Set environment to production mode
   - Remove all demo-related feature flags

2. **Service Architecture**:
   - Delete all demo service files (`demo_auth_service.dart`, `demo_content_service.dart`, `demo_search_service.dart`)
   - Remove service wrapper classes that switch between demo/production
   - Update all imports to use production services directly
   - Remove demo mode conditionals from all service initializations

3. **Code Cleanup**:
   - Remove all demo mode checks and conditions throughout the app
   - Remove mock data generation and placeholder content
   - Clean up test/sample data references
   - Remove demo-related debug prints and logs

4. **Asset Cleanup**:
   - Remove placeholder icons and images
   - Clean up any demo-specific assets
   - Update asset references to use production resources

5. **Testing Integration**:
   - Update testing service to work without demo mode
   - Ensure all production services are properly initialized
   - Verify no broken imports or missing dependencies

## Constraints
- Maintain all existing functionality, just remove demo mode
- Preserve production Supabase integration
- Keep error handling for production scenarios
- Maintain code structure and patterns where possible
- Ensure clean build with no demo mode references

## Task Breakdown
This will be broken down into specific, actionable tasks in the implementation checklist.
