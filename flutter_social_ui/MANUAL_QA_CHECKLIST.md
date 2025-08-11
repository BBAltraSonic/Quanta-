# Post Detail Screen - Manual QA Checklist

## Pre-Test Setup
- [ ] Ensure Supabase database is properly configured
- [ ] Verify test user accounts exist with different roles
- [ ] Confirm test posts exist with various content types (video, image)
- [ ] Check that test avatars are created and associated with posts
- [ ] Verify network connectivity for testing offline scenarios

## A. Playback & Controls

### Video Autoplay
- [ ] **Test Case**: Open Post Detail screen with video post
  - **Expected**: Video starts playing automatically
  - **Actual**: ___________
- [ ] **Test Case**: Navigate away from Post Detail and return
  - **Expected**: Video resumes from last position
  - **Actual**: ___________

### Play/Pause Controls
- [ ] **Test Case**: Tap video area while playing
  - **Expected**: Video pauses, play button overlay appears
  - **Actual**: ___________
- [ ] **Test Case**: Tap video area while paused
  - **Expected**: Video resumes, play button overlay disappears
  - **Actual**: ___________

### Mute/Unmute
- [ ] **Test Case**: Tap volume button in top overlay
  - **Expected**: Video mutes, volume icon changes to muted state
  - **Actual**: ___________
- [ ] **Test Case**: Tap mute button again
  - **Expected**: Video unmutes, volume icon returns to normal
  - **Actual**: ___________
- [ ] **Test Case**: Setting persists across app sessions
  - **Expected**: Mute preference is remembered
  - **Actual**: ___________

### Non-Video Content
- [ ] **Test Case**: Open Post Detail with image post
  - **Expected**: Image displays, no video controls visible
  - **Actual**: ___________
- [ ] **Test Case**: Post with invalid/broken video URL
  - **Expected**: Error state shown, playback controls disabled
  - **Actual**: ___________

## B. Like / Reactions

### Basic Like Functionality
- [ ] **Test Case**: Tap heart icon on unliked post
  - **Expected**: Heart fills red, like count increases by 1
  - **Actual**: ___________
- [ ] **Test Case**: Tap heart icon on already liked post
  - **Expected**: Heart becomes outline, like count decreases by 1
  - **Actual**: ___________

### Double-Tap Like
- [ ] **Test Case**: Double-tap video area quickly
  - **Expected**: Post is liked, heart animation plays
  - **Actual**: ___________
- [ ] **Test Case**: Double-tap when already liked
  - **Expected**: Post remains liked, no duplicate action
  - **Actual**: ___________

### Optimistic Updates
- [ ] **Test Case**: Like post with poor network
  - **Expected**: UI updates immediately, reverts if network fails
  - **Actual**: ___________
- [ ] **Test Case**: Network failure during like
  - **Expected**: Error message shown with retry option
  - **Actual**: ___________

### View Likers
- [ ] **Test Case**: Tap like count number
  - **Expected**: Modal/screen opens showing users who liked
  - **Actual**: ___________

## C. Comments

### Comment Modal Opening
- [ ] **Test Case**: Tap comment icon
  - **Expected**: Comments modal slides up from bottom
  - **Actual**: ___________
- [ ] **Test Case**: Modal shows correct comment count in header
  - **Expected**: Count matches post's comment count
  - **Actual**: ___________

### Adding Comments
- [ ] **Test Case**: Type comment and tap send
  - **Expected**: Comment appears at top, input clears, count updates
  - **Actual**: ___________
- [ ] **Test Case**: Submit empty comment
  - **Expected**: Nothing happens, no empty comment created
  - **Actual**: ___________
- [ ] **Test Case**: Comment submission fails
  - **Expected**: Error shown, text remains in input, retry option available
  - **Actual**: ___________

### Comment Display
- [ ] **Test Case**: Comments load with pagination
  - **Expected**: Initial 20 comments load, scroll for more
  - **Actual**: ___________
- [ ] **Test Case**: Scroll to bottom of comments
  - **Expected**: More comments load automatically
  - **Actual**: ___________

### Realtime Updates
- [ ] **Test Case**: Have another user comment on same post
  - **Expected**: New comment appears immediately without refresh
  - **Actual**: ___________
- [ ] **Test Case**: Notification for new comment from others
  - **Expected**: Brief notification shows "Someone commented"
  - **Actual**: ___________

### Comment Management
- [ ] **Test Case**: Delete own comment
  - **Expected**: Confirmation dialog, comment removes on confirm
  - **Actual**: ___________
- [ ] **Test Case**: Try to delete other user's comment
  - **Expected**: Delete option not available
  - **Actual**: ___________

## D. Share & Copy Link

### Native Share
- [ ] **Test Case**: Tap share button
  - **Expected**: Native share sheet opens with post URL and description
  - **Actual**: ___________
- [ ] **Test Case**: Complete share to platform (e.g., Messages)
  - **Expected**: Share completes, share count increments
  - **Actual**: ___________

### Copy Link
- [ ] **Test Case**: Open more menu, tap "Copy Link"
  - **Expected**: Link copied to clipboard, success toast shown
  - **Actual**: ___________
- [ ] **Test Case**: Paste link in another app
  - **Expected**: Correct post URL is pasted
  - **Actual**: ___________

## E. Follow & Profile

### Avatar Navigation
- [ ] **Test Case**: Tap avatar image
  - **Expected**: Navigate to chat screen with avatar
  - **Actual**: ___________
- [ ] **Test Case**: Tap username
  - **Expected**: Navigate to avatar profile/chat
  - **Actual**: ___________

### Follow Functionality
- [ ] **Test Case**: Tap "Follow" button on unfollowed avatar
  - **Expected**: Button disappears, success message shown
  - **Actual**: ___________
- [ ] **Test Case**: Unfollow from avatar's profile (separate test)
  - **Expected**: Follow button reappears on posts
  - **Actual**: ___________

### Optimistic Updates
- [ ] **Test Case**: Follow with poor network
  - **Expected**: UI updates immediately, reverts if fails
  - **Actual**: ___________

## F. More / Options Menu

### Menu Opening
- [ ] **Test Case**: Tap three-dot menu button
  - **Expected**: Bottom sheet opens with all options
  - **Actual**: ___________

### Report Functionality
- [ ] **Test Case**: Tap "Report" option
  - **Expected**: Report dialog opens with reason options
  - **Actual**: ___________
- [ ] **Test Case**: Submit report with reason
  - **Expected**: Success message, thank you confirmation
  - **Actual**: ___________

### Block User
- [ ] **Test Case**: Tap "Block User"
  - **Expected**: Confirmation dialog with clear warning
  - **Actual**: ___________
- [ ] **Test Case**: Confirm block
  - **Expected**: User blocked, their posts removed from feed
  - **Actual**: ___________

### Bookmark/Save
- [ ] **Test Case**: Tap bookmark from more menu
  - **Expected**: Post saved, success message shown
  - **Actual**: ___________
- [ ] **Test Case**: Unbookmark saved post
  - **Expected**: Post removed from saved, confirmation shown
  - **Actual**: ___________

### Download (Video Posts)
- [ ] **Test Case**: Tap "Download" on video post
  - **Expected**: Download starts, progress shown
  - **Actual**: ___________
- [ ] **Test Case**: Download on image post
  - **Expected**: Download option not available or works correctly
  - **Actual**: ___________

## G. Views & Analytics

### View Counting
- [ ] **Test Case**: Watch video for 2+ seconds
  - **Expected**: View count increments after threshold
  - **Actual**: ___________
- [ ] **Test Case**: Quickly scroll past video
  - **Expected**: View count does not increment
  - **Actual**: ___________

### Analytics Events
- [ ] **Test Case**: Perform various actions (like, comment, share)
  - **Expected**: Events logged correctly (check logs)
  - **Actual**: ___________

## H. Optimistic Updates & Error Handling

### Network Error Scenarios
- [ ] **Test Case**: Like post with no network
  - **Expected**: Action queued, executes when network returns
  - **Actual**: ___________
- [ ] **Test Case**: Add comment while offline
  - **Expected**: Comment queued, posts when online
  - **Actual**: ___________

### Retry Functionality
- [ ] **Test Case**: Network error with retry button
  - **Expected**: Retry button works, action completes on retry
  - **Actual**: ___________

### Loading States
- [ ] **Test Case**: Slow network during comment load
  - **Expected**: Loading spinner shown, comments appear when loaded
  - **Actual**: ___________

## I. Security & Permissions

### Authentication Required
- [ ] **Test Case**: Perform action while logged out
  - **Expected**: Login prompt or authentication error shown
  - **Actual**: ___________

### Unauthorized Actions
- [ ] **Test Case**: Try to delete other user's content
  - **Expected**: Action blocked, appropriate error shown
  - **Actual**: ___________

## J. Performance & UX

### Loading Performance
- [ ] **Test Case**: Open Post Detail screen
  - **Expected**: Loads within 2 seconds, smooth animations
  - **Actual**: ___________

### Memory Management
- [ ] **Test Case**: Scroll through multiple video posts
  - **Expected**: No memory leaks, smooth performance
  - **Actual**: ___________

### Smooth Interactions
- [ ] **Test Case**: Rapid tapping of like button
  - **Expected**: No duplicate actions, smooth animations
  - **Actual**: ___________

### Accessibility
- [ ] **Test Case**: Use with screen reader
  - **Expected**: All buttons have proper labels, content is readable
  - **Actual**: ___________

## K. Edge Cases

### Empty States
- [ ] **Test Case**: Post with no comments
  - **Expected**: "No comments yet" message shown
  - **Actual**: ___________
- [ ] **Test Case**: Post with no likes
  - **Expected**: Like count shows 0 or is hidden
  - **Actual**: ___________

### Large Numbers
- [ ] **Test Case**: Post with 1000+ likes
  - **Expected**: Count formatted as "1K"
  - **Actual**: ___________
- [ ] **Test Case**: Post with 1M+ views
  - **Expected**: Count formatted as "1M"
  - **Actual**: ___________

### Content Limits
- [ ] **Test Case**: Very long comment (500+ characters)
  - **Expected**: Comment truncated or scrollable
  - **Actual**: ___________
- [ ] **Test Case**: Post with many hashtags
  - **Expected**: Only first few hashtags shown
  - **Actual**: ___________

## Test Results Summary

### Overall Assessment
- **Total Test Cases**: ___/87
- **Passed**: ___
- **Failed**: ___
- **Blocked**: ___

### Critical Issues Found
1. _________________________________
2. _________________________________
3. _________________________________

### Minor Issues Found
1. _________________________________
2. _________________________________
3. _________________________________

### Performance Notes
- Load time: _____ seconds
- Memory usage: _____ MB
- Battery impact: _____

### Recommendations
1. _________________________________
2. _________________________________
3. _________________________________

### Sign-off
- **Tester**: ________________
- **Date**: ________________
- **Build Version**: ________________
- **Ready for Release**: [ ] Yes [ ] No [ ] With Conditions
