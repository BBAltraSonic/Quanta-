# In-App Browser for External Tools Implementation Plan

## Overview
This plan outlines the implementation of an in-app browser for external content-creation tools in the Create Post page. Users will be able to access external tools without leaving the app, and optionally import generated content back into their post drafts.

## Current State Analysis
- The app already supports importing content from external platforms (Hugging Face, Runway ML, Midjourney, Stable Diffusion, DALL-E)
- Content import is currently done via URL input in the existing import flow
- No in-app browser functionality exists yet
- No webview dependencies are currently included in pubspec.yaml

## Detailed Implementation Plan

### 1. Dependency Management
Add `webview_flutter` to the project dependencies in `pubspec.yaml`.

### 2. Data Model Enhancement
Extend the existing `ExternalPlatform` model to include:
- Direct URLs to the tool platforms
- Import callback URLs for returning content to the app
- Platform-specific configurations

### 3. Service Layer Updates
Update `ContentUploadService` to:
- Provide direct tool URLs for each platform
- Handle content import from in-app browser sessions
- Maintain backward compatibility with existing URL import functionality

### 4. UI Implementation
Modify `ContentUploadScreen` to add:
- A new "Tools" section below the existing media picker
- Cards/buttons for each external tool with:
  - Name
  - Short description
  - Icon/logo
- Integration with the new in-app browser

### 5. In-App Browser Screen
Create a new `InAppBrowserScreen` that:
- Uses `webview_flutter` to display external tools
- Provides navigation controls (back, forward, refresh)
- Implements a "Return to Draft" button for content import
- Handles loading errors gracefully
- Provides fallback to external browser option

### 6. Navigation & Data Flow
Implement navigation flow:
- ContentUploadScreen → InAppBrowserScreen
- InAppBrowserScreen → ContentUploadScreen (with imported content)

## Workflow Diagram

```mermaid
graph TD
    A[ContentUploadScreen] --> B{User selects tool}
    B --> C[Show tool cards]
    C --> D[User taps tool card]
    D --> E[Launch InAppBrowserScreen]
    E --> F{WebView loads}
    F -->|Success| G[Show external tool]
    F -->|Failure| H[Show error with fallback option]
    G --> I{User creates content}
    I --> J[User taps "Return to Draft"]
    J --> K[Import content to draft]
    K --> A
    G --> L[User navigates back]
    L --> A
    H --> M[Open in external browser]
    M --> A
```

## Technical Considerations

### Error Handling
- Implement graceful error handling for WebView loading failures
- Provide clear error messages to users
- Offer fallback option to open tools in external browser

### State Management
- Preserve draft state when navigating to/from the in-app browser
- Handle back navigation properly to maintain user context
- Ensure content import maintains draft data integrity

### Platform Support
- Support all currently integrated platforms:
  - Hugging Face
  - Runway ML
  - Midjourney
  - Stable Diffusion
  - DALL-E

## Acceptance Criteria
- Profile page always represents an avatar, never the creator
- Avatar profile supports Owner View and Public View
- Users can switch between avatars
- Create Post page contains a Tools Section with working in-app WebView links
- Returning from WebView preserves the draft state
- Error handling ensures smooth UX

## Implementation Steps
1. Add webview_flutter dependency
2. Create/extend data models for external tools
3. Update ContentUploadService with tool URLs
4. Add Tools Section to ContentUploadScreen
5. Create InAppBrowserScreen
6. Implement navigation and data flow
7. Add error handling and fallback options
8. Test with all supported platforms
9. Verify draft state preservation
10. Validate profile page avatar representation