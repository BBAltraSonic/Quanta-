#!/usr/bin/env dart

import 'dart:io';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../lib/services/data_migration_service.dart';
import '../lib/services/auth_service.dart';

/// Command-line script for running data migration
///
/// Usage:
///   dart scripts/data_migration_script.dart [options]
///
/// Options:
///   --dry-run          Run migration without making changes
///   --no-backup        Skip creating backup (not recommended)
///   --stats-only       Only show migration statistics
///   --help             Show this help message

void main(List<String> arguments) async {
  // Parse command line arguments
  final args = _parseArguments(arguments);

  if (args['help'] == true) {
    _printHelp();
    return;
  }

  try {
    // Initialize Supabase
    await _initializeSupabase();

    // Create services
    final authService = AuthService();
    final migrationService = DataMigrationService(authService: authService);

    if (args['stats-only'] == true) {
      await _showMigrationStats(migrationService);
      return;
    }

    // Run migration
    await _runMigration(
      migrationService,
      dryRun: args['dry-run'] == true,
      createBackup: args['no-backup'] != true,
    );
  } catch (e) {
    print('❌ Migration script failed: $e');
    exit(1);
  }
}

/// Parse command line arguments
Map<String, dynamic> _parseArguments(List<String> arguments) {
  final args = <String, dynamic>{};

  for (final arg in arguments) {
    switch (arg) {
      case '--dry-run':
        args['dry-run'] = true;
        break;
      case '--no-backup':
        args['no-backup'] = true;
        break;
      case '--stats-only':
        args['stats-only'] = true;
        break;
      case '--help':
      case '-h':
        args['help'] = true;
        break;
      default:
        print('⚠️  Unknown argument: $arg');
        break;
    }
  }

  return args;
}

/// Print help message
void _printHelp() {
  print('''
Data Migration Script - Avatar-Centric Profile System

This script migrates existing users from a user-centric to avatar-centric profile system.

Usage:
  dart scripts/data_migration_script.dart [options]

Options:
  --dry-run          Run migration without making changes (recommended for testing)
  --no-backup        Skip creating backup (not recommended for production)
  --stats-only       Only show migration statistics without running migration
  --help, -h         Show this help message

Examples:
  # Show current migration status
  dart scripts/data_migration_script.dart --stats-only

  # Test migration without making changes
  dart scripts/data_migration_script.dart --dry-run

  # Run actual migration with backup
  dart scripts/data_migration_script.dart

Environment Variables Required:
  SUPABASE_URL       - Your Supabase project URL
  SUPABASE_ANON_KEY  - Your Supabase anonymous key

Note: Make sure to test with --dry-run first and have database backups before running in production.
''');
}

/// Initialize Supabase connection
Future<void> _initializeSupabase() async {
  final supabaseUrl = Platform.environment['SUPABASE_URL'];
  final supabaseAnonKey = Platform.environment['SUPABASE_ANON_KEY'];

  if (supabaseUrl == null || supabaseAnonKey == null) {
    throw Exception(
      'Missing required environment variables: SUPABASE_URL and SUPABASE_ANON_KEY\n'
      'Please set these in your .env file or environment.',
    );
  }

  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

  print('✅ Connected to Supabase');
}

/// Show migration statistics
Future<void> _showMigrationStats(DataMigrationService migrationService) async {
  print('📊 Getting migration statistics...\n');

  final stats = await migrationService.getMigrationStats();

  if (stats.containsKey('error')) {
    print('❌ Error getting stats: ${stats['error']}');
    return;
  }

  print('Migration Statistics:');
  print('═══════════════════');
  print('Total Users: ${stats['total_users']}');
  print('Migrated Users: ${stats['migrated_users']}');
  print('Users Needing Migration: ${stats['users_needing_migration']}');
  print('Total Avatars: ${stats['total_avatars']}');
  print('Migrated Avatars: ${stats['migrated_avatars']}');
  print('Migration Progress: ${stats['migration_completion_percentage']}%');

  if (stats['users_needing_migration'] > 0) {
    print(
      '\n⚠️  ${stats['users_needing_migration']} users still need migration',
    );
    print('Run the migration script to complete the process.');
  } else {
    print('\n✅ All users have been migrated to avatar-centric profiles');
  }
}

/// Run the migration process
Future<void> _runMigration(
  DataMigrationService migrationService, {
  required bool dryRun,
  required bool createBackup,
}) async {
  print('🚀 Starting data migration to avatar-centric system');
  print('Settings:');
  print('  Dry Run: ${dryRun ? 'YES' : 'NO'}');
  print('  Create Backup: ${createBackup ? 'YES' : 'NO'}');
  print('');

  if (!dryRun) {
    print('⚠️  WARNING: This will modify your database!');
    print('Make sure you have a backup before proceeding.');
    print('');

    stdout.write('Continue? (y/N): ');
    final input = stdin.readLineSync()?.toLowerCase().trim();
    if (input != 'y' && input != 'yes') {
      print('Migration cancelled.');
      return;
    }
    print('');
  }

  final stopwatch = Stopwatch()..start();

  try {
    final result = await migrationService.migrateExistingUsers(
      dryRun: dryRun,
      createBackup: createBackup,
    );

    stopwatch.stop();

    if (result.success) {
      print('✅ Migration completed successfully!');
      print('Time taken: ${stopwatch.elapsed.inSeconds} seconds');
      print('');
      _printMigrationDetails(result);
    } else {
      print('❌ Migration completed with errors');
      print('Time taken: ${stopwatch.elapsed.inSeconds} seconds');
      print('');
      _printMigrationDetails(result);

      if (result.errors.isNotEmpty) {
        print('\nErrors:');
        for (final error in result.errors) {
          print('  • $error');
        }
      }
    }
  } catch (e) {
    stopwatch.stop();
    print('❌ Migration failed: $e');
    print('Time taken: ${stopwatch.elapsed.inSeconds} seconds');
    exit(1);
  }
}

/// Print migration result details
void _printMigrationDetails(MigrationResult result) {
  print('Migration Results:');
  print('═════════════════');
  print('Status: ${result.success ? 'SUCCESS' : 'FAILED'}');
  print('Message: ${result.message}');

  if (result.details.isNotEmpty) {
    print('\nDetails:');
    result.details.forEach((key, value) {
      final formattedKey = key
          .replaceAll('_', ' ')
          .split(' ')
          .map((word) => word[0].toUpperCase() + word.substring(1))
          .join(' ');
      print('  $formattedKey: $value');
    });
  }
}
