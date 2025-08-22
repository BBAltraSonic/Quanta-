# Avatar-Centric Profile Migration Guide

This document provides comprehensive instructions for migrating from a user-centric to avatar-centric profile system.

## Overview

The migration transforms the existing user-centric profile system where users are the primary entities into an avatar-centric system where virtual avatars become the main content creators and public-facing entities.

## Migration Components

### 1. Database Migration (`database_avatar_migration.sql`)

- SQL functions for creating default avatars
- User migration functions
- Rollback mechanisms
- Validation functions
- Performance monitoring

### 2. Application Migration Service (`lib/services/data_migration_service.dart`)

- Dart service for orchestrating migration
- Backup creation and rollback
- Error handling and reporting
- Statistics and progress tracking

### 3. Migration Script (`scripts/data_migration_script.dart`)

- Command-line interface for running migrations
- Dry-run capabilities
- Progress reporting
- Interactive confirmation

### 4. Migration Validator (`scripts/migration_validator.dart`)

- Data integrity validation
- Issue detection and fixing
- Comprehensive reporting
- Post-migration verification

## Pre-Migration Checklist

### 1. Environment Setup

- [ ] Ensure Supabase connection is working
- [ ] Set environment variables: `SUPABASE_URL`, `SUPABASE_ANON_KEY`
- [ ] Verify database backup capabilities
- [ ] Test database connection with migration scripts

### 2. Data Preparation

- [ ] Run pre-migration validation: `dart scripts/migration_validator.dart`
- [ ] Review and resolve any critical issues
- [ ] Ensure no active user sessions during migration
- [ ] Create full database backup

### 3. Testing

- [ ] Test migration on a copy of production data
- [ ] Verify rollback procedures work correctly
- [ ] Test application functionality post-migration
- [ ] Performance test with expected data volumes

## Migration Process

### Step 1: Database Schema Migration

First, apply the database-level migration:

```sql
-- Connect to your Supabase database and run:
\i database_avatar_migration.sql
```

This creates all necessary functions and backup tables.

### Step 2: Pre-Migration Validation

Run the validator to check for issues:

```bash
# Basic validation
dart scripts/migration_validator.dart

# Detailed validation with automatic fixes
dart scripts/migration_validator.dart --detailed --fix-issues
```

### Step 3: Dry Run Migration

Test the migration without making changes:

```bash
# Show current statistics
dart scripts/data_migration_script.dart --stats-only

# Run dry-run migration
dart scripts/data_migration_script.dart --dry-run
```

### Step 4: Production Migration

Run the actual migration:

```bash
# Full migration with backup
dart scripts/data_migration_script.dart

# Migration without backup (not recommended)
dart scripts/data_migration_script.dart --no-backup
```

### Step 5: Post-Migration Validation

Verify the migration completed successfully:

```bash
# Validate migration integrity
dart scripts/migration_validator.dart --detailed

# Check migration statistics
dart scripts/data_migration_script.dart --stats-only
```

## Batch Migration (for Large Datasets)

For databases with many users, use batch migration:

```sql
-- Migrate in batches of 100 users
SELECT migrate_users_batch(100, 0);   -- First batch
SELECT migrate_users_batch(100, 100); -- Second batch
-- Continue until has_more = false
```

## Monitoring Migration Progress

### Real-time Progress Monitoring

```sql
-- Get detailed migration progress
SELECT get_detailed_migration_progress();

-- Check performance statistics
SELECT get_migration_performance_stats();

-- View recent migration activity
SELECT * FROM migration_log
WHERE created_at > NOW() - INTERVAL '1 hour'
ORDER BY created_at DESC;
```

### Application-level Monitoring

```dart
// Check migration statistics
final migrationService = DataMigrationService(authService: authService);
final stats = await migrationService.getMigrationStats();
print('Migration Progress: ${stats['migration_completion_percentage']}%');
```

## Rollback Procedures

### Automatic Rollback

If migration fails, automatic rollback is attempted:

```dart
// Rollback is automatically triggered on migration failure
// Check migration logs for rollback status
```

### Manual Rollback

For manual rollback of specific users:

```sql
-- Rollback specific user
SELECT rollback_user_migration('user-uuid-here');

-- Rollback all migrations (use with extreme caution)
SELECT rollback_all_migrations();
```

### Application-level Rollback

```bash
# The migration service includes rollback capabilities
# Check the migration result for rollback information
```

## Troubleshooting

### Common Issues

#### 1. Users Without Active Avatars

**Symptom:** Users exist but have no active_avatar_id
**Solution:** Run the migration script to create default avatars

#### 2. Orphaned Avatars

**Symptom:** Avatars exist but their owner_user_id points to non-existent users
**Solution:** Run validator with `--fix-issues` to clean up orphaned avatars

#### 3. Posts Without Avatar Associations

**Symptom:** Posts exist but have no avatar_id
**Solution:** Manual review required to associate posts with appropriate avatars

#### 4. Invalid Follow References

**Symptom:** Follows point to non-existent avatars
**Solution:** Run validator with `--fix-issues` to clean up invalid follows

### Error Recovery

#### Migration Fails Midway

1. Check migration logs: `SELECT * FROM migration_log ORDER BY created_at DESC;`
2. Identify failed users from logs
3. Fix underlying issues
4. Resume migration for remaining users

#### Database Connection Issues

1. Verify environment variables are set correctly
2. Check Supabase project status
3. Ensure network connectivity
4. Retry with exponential backoff

#### Memory Issues (Large Datasets)

1. Use batch migration instead of full migration
2. Reduce batch size: `SELECT migrate_users_batch(50, offset);`
3. Monitor database performance during migration
4. Consider running during off-peak hours

## Performance Considerations

### Database Performance

- Migration creates indexes automatically
- Monitor database CPU and memory usage
- Consider running during low-traffic periods
- Use batch migration for datasets > 10,000 users

### Application Performance

- Migration service includes caching mechanisms
- Real-time subscriptions handle live updates
- Consider temporary read-only mode during migration

### Network Performance

- Migration minimizes network round-trips
- Batch operations reduce connection overhead
- Progress reporting is optimized for large datasets

## Validation and Testing

### Pre-Migration Testing

1. Clone production database to staging
2. Run full migration on staging data
3. Test application functionality
4. Measure migration performance
5. Validate rollback procedures

### Post-Migration Testing

1. Verify all users have active avatars
2. Check avatar-profile navigation works
3. Validate content associations are correct
4. Test follow relationships function properly
5. Confirm no data loss occurred

### Automated Testing

```bash
# Run migration tests
flutter test test/services/data_migration_service_test.dart

# Run integration tests
flutter test test/integration/
```

## Security Considerations

### Data Protection

- All migrations include backup creation
- Rollback mechanisms preserve original data
- No sensitive data is logged or exposed
- Migration logs exclude PII

### Access Control

- Migration requires appropriate database permissions
- Environment variables should be secured
- Migration scripts should run in controlled environment
- Audit logs track all migration activities

### Compliance

- Migration preserves all user data relationships
- No data is deleted during normal migration
- Rollback capabilities ensure data recovery
- Migration logs provide audit trail

## Support and Maintenance

### Monitoring

- Set up alerts for migration failures
- Monitor database performance during migration
- Track migration progress in real-time
- Log all migration activities for audit

### Maintenance

- Clean up migration logs after successful completion
- Remove backup tables after verification period
- Update documentation based on lessons learned
- Plan for future schema migrations

### Support Contacts

- Database issues: Check Supabase dashboard and logs
- Application issues: Review Flutter/Dart error logs
- Migration issues: Check migration_log table
- Performance issues: Monitor database metrics

## Appendix

### Environment Variables

```bash
# Required for migration scripts
SUPABASE_URL=your-supabase-project-url
SUPABASE_ANON_KEY=your-supabase-anon-key

# Optional for enhanced logging
MIGRATION_LOG_LEVEL=INFO
MIGRATION_BATCH_SIZE=100
```

### Database Schema Changes

The migration adds these key relationships:

- `users.active_avatar_id` → `avatars.id`
- `posts.avatar_id` → `avatars.id` (existing)
- `follows.avatar_id` → `avatars.id` (existing)

### Migration Metrics

Track these key metrics during migration:

- Users migrated per minute
- Average migration time per user
- Error rate and types
- Database performance impact
- Memory and CPU usage

### Recovery Procedures

1. **Partial Migration Failure:** Resume from last successful batch
2. **Complete Migration Failure:** Use automatic rollback
3. **Data Corruption:** Restore from backup and retry
4. **Performance Issues:** Switch to batch migration mode
