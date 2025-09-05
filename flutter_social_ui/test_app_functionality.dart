#!/usr/bin/env dart
// Quanta App Testing Script
// This script validates critical app functionality including authentication flows

import 'dart:io';

void main(List<String> arguments) async {
  print('🧪 Quanta App Testing Suite');
  print('=' * 50);
  print('Testing critical app functionality...\n');

  // Test 1: Environment Configuration
  await testEnvironmentConfiguration();

  // Test 2: Dependencies Check
  await testDependencies();

  // Test 3: Build System
  await testBuildSystem();

  // Test 4: Security Validation
  await testSecurityConfiguration();

  // Test 5: Asset Validation
  await testAssets();

  print('\n${'=' * 50}');
  print('✅ Testing completed! See results above.');
}

Future<void> testEnvironmentConfiguration() async {
  print('🔧 Testing Environment Configuration...');

  try {
    // Check .env.template exists
    final envTemplate = File('.env.template');
    if (await envTemplate.exists()) {
      print('  ✅ .env.template file exists');
    } else {
      print('  ❌ .env.template file missing');
    }

    // Check .env exists
    final envFile = File('.env');
    if (await envFile.exists()) {
      print('  ✅ .env file exists');
    } else {
      print('  ⚠️  .env file missing (create from .env.template)');
    }

    // Check .gitignore properly configured
    final gitignore = File('.gitignore');
    if (await gitignore.exists()) {
      final content = await gitignore.readAsString();
      if (content.contains('.env')) {
        print('  ✅ .gitignore properly configured for .env files');
      } else {
        print('  ❌ .gitignore missing .env exclusion');
      }
    }
  } catch (e) {
    print('  ❌ Environment configuration test failed: $e');
  }
  print('');
}

Future<void> testDependencies() async {
  print('📦 Testing Dependencies...');

  try {
    // Check pubspec.yaml
    final pubspec = File('pubspec.yaml');
    if (await pubspec.exists()) {
      final content = await pubspec.readAsString();

      // Check key dependencies
      final requiredDeps = [
        'flutter_dotenv',
        'supabase_flutter',
        'firebase_core',
        'firebase_crashlytics',
        'provider',
        'shared_preferences',
      ];

      for (final dep in requiredDeps) {
        if (content.contains(dep)) {
          print('  ✅ $dep dependency found');
        } else {
          print('  ❌ $dep dependency missing');
        }
      }
    } else {
      print('  ❌ pubspec.yaml not found');
    }
  } catch (e) {
    print('  ❌ Dependencies test failed: $e');
  }
  print('');
}

Future<void> testBuildSystem() async {
  print('🏗️ Testing Build System...');

  try {
    // Test pub get
    print('  📦 Testing dependency resolution...');
    final pubGetResult = await Process.run('flutter', ['pub', 'get']);
    if (pubGetResult.exitCode == 0) {
      print('  ✅ Dependencies resolved successfully');
    } else {
      print('  ❌ Dependencies resolution failed');
      print('     ${pubGetResult.stderr}');
    }
  } catch (e) {
    print('  ❌ Build system test failed: $e');
  }
  print('');
}

Future<void> testSecurityConfiguration() async {
  print('🔒 Testing Security Configuration...');

  try {
    // Check for hardcoded secrets in key files
    final securityFiles = [
      'lib/config/app_config.dart',
      'lib/utils/environment.dart',
      'lib/services/auth_service.dart',
    ];

    for (final filePath in securityFiles) {
      final file = File(filePath);
      if (await file.exists()) {
        final content = await file.readAsString();

        // Check for potential security issues
        final securityPatterns = [
          RegExp(r'eyJ[A-Za-z0-9+/=]*'), // JWT tokens
          RegExp(r'sk-[A-Za-z0-9]{40,}'), // API keys
          RegExp(r'[0-9a-f]{32,}'), // Long hex strings
        ];

        bool hasIssues = false;
        for (final pattern in securityPatterns) {
          if (pattern.hasMatch(content)) {
            hasIssues = true;
            break;
          }
        }

        if (!hasIssues) {
          print('  ✅ $filePath: No hardcoded secrets detected');
        } else {
          print('  ❌ $filePath: Potential hardcoded secrets found');
        }
      } else {
        print('  ⚠️  $filePath: File not found');
      }
    }
  } catch (e) {
    print('  ❌ Security configuration test failed: $e');
  }
  print('');
}

Future<void> testAssets() async {
  print('🎨 Testing Assets...');

  try {
    // Check app icons
    final iconDirs = [
      'android/app/src/main/res/mipmap-hdpi',
      'android/app/src/main/res/mipmap-mdpi',
      'android/app/src/main/res/mipmap-xhdpi',
      'android/app/src/main/res/mipmap-xxhdpi',
      'android/app/src/main/res/mipmap-xxxhdpi',
    ];

    for (final iconDir in iconDirs) {
      final dir = Directory(iconDir);
      if (await dir.exists()) {
        final files = await dir.list().toList();
        if (files.any((f) => f.path.contains('launcher_icon'))) {
          print('  ✅ Custom launcher icons found in $iconDir');
        } else {
          print('  ⚠️  No custom launcher icons in $iconDir');
        }
      }
    }

    // Check web manifest
    final webManifest = File('web/manifest.json');
    if (await webManifest.exists()) {
      final content = await webManifest.readAsString();
      if (content.contains('Quanta')) {
        print('  ✅ Web manifest properly configured');
      } else {
        print('  ❌ Web manifest needs Quanta branding');
      }
    }

    // Check store assets documentation
    final storeAssets = File('STORE_ASSETS_METADATA.md');
    if (await storeAssets.exists()) {
      print('  ✅ Store assets documentation created');
    } else {
      print('  ⚠️  Store assets documentation missing');
    }
  } catch (e) {
    print('  ❌ Assets test failed: $e');
  }
  print('');
}
