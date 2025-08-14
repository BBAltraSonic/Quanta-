# Database Schema Fixes Deployment Guide

## Overview
This guide will help you apply the necessary database schema fixes to resolve the runtime errors seen in the Flutter app.

## Errors Being Fixed
1. ❌ `Failed to get user posts: column posts.user_id does not exist`
2. ❌ `Failed to flush analytics events: Could not find the 'event_data' column of 'analytics_events'`
3. ❌ `Error getting unread count: relation "public.user_read_messages" does not exist`

## Deployment Steps

### Step 1: Access Supabase Dashboard
1. Go to your Supabase project: https://neyfqiauyxfurfhdtrug.supabase.co
2. Navigate to **SQL Editor**

### Step 2: Execute Schema Fixes
1. Copy the contents of `database_schema_fixes.sql`
2. Paste into the SQL Editor
3. Click **Run** to execute all fixes

### Step 3: Verify Deployment
After running the script, you should see these success messages:
- ✅ `SUCCESS: All required columns and tables are present!`
- ✅ `Schema fixes completed successfully!`
- ✅ Test function results showing unread count

## What Gets Fixed

### 1. Posts Table - user_id Column
- **Problem**: App expects `posts.user_id` but table only has `avatar_id`
- **Solution**: 
  - Adds `user_id` column to posts table
  - Populates it based on avatar ownership
  - Creates trigger to auto-populate for new posts

### 2. Analytics Events - event_data Column  
- **Problem**: App expects `event_data` but table has `properties`
- **Solution**:
  - Adds `event_data` column as alias
  - Creates sync trigger to keep both columns in sync
  - Maintains backward compatibility

### 3. User Read Messages Table
- **Problem**: Missing `user_read_messages` table for notification tracking
- **Solution**:
  - Creates complete table with proper schema
  - Adds RLS policies for security
  - Includes helper function `get_unread_count()`

### 4. Additional Fixes
- Ensures `views_count` column exists in posts
- Creates proper indexes for performance
- Adds verification queries to confirm all fixes

## Post-Deployment Verification

After applying the fixes, restart your Flutter app and verify:

1. **Profile Screen**: Should load without "user_id does not exist" errors
2. **Analytics**: Should track events without "event_data" errors  
3. **Notifications**: Should check unread count without table missing errors

## Expected App Behavior After Fixes

✅ Profile screen loads successfully
✅ Analytics events are tracked properly
✅ Notification system works without errors
✅ All database queries execute successfully
✅ Performance should improve due to proper indexing

## Troubleshooting

If you see any errors after deployment:

1. **Check the SQL Editor output** for any failed statements
2. **Verify RLS policies** are properly created
3. **Confirm all indexes** were created successfully
4. **Test the functions** by running:
   ```sql
   SELECT get_unread_count('00000000-0000-0000-0000-000000000000'::uuid);
   ```

## Rollback Plan

If issues occur, you can rollback by:
1. Dropping the newly created triggers
2. Removing the added columns (optional)
3. Dropping the user_read_messages table

However, these changes are designed to be non-destructive and maintain compatibility.
