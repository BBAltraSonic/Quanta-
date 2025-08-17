#!/usr/bin/env dart

import 'dart:io';

void main() {
  print('🔒 Running Quanta Security Check...\n');

  bool allChecksPassed = true;

  // Check 1: Ensure .env is in .gitignore
  print('1. Checking .gitignore for .env files...');
  final gitignoreFile = File('.gitignore');
  if (gitignoreFile.existsSync()) {
    final gitignoreContent = gitignoreFile.readAsStringSync();
    if (gitignoreContent.contains('.env')) {
      print('   ✅ .env files are properly ignored');
    } else {
      print('   ❌ .env files are NOT in .gitignore - SECURITY RISK!');
      allChecksPassed = false;
    }
  } else {
    print('   ❌ .gitignore file not found');
    allChecksPassed = false;
  }

  // Check 2: Ensure .env.example exists
  print('\n2. Checking for .env.example template...');
  final envExampleFile = File('.env.example');
  if (envExampleFile.existsSync()) {
    print('   ✅ .env.example template exists');
  } else {
    print('   ❌ .env.example template missing');
    allChecksPassed = false;
  }

  // Check 3: Scan for hardcoded secrets
  print('\n3. Scanning for hardcoded secrets...');
  final secretPatterns = [
    RegExp(r'eyJ[A-Za-z0-9+/=]+'), // JWT tokens
    RegExp(r'sk-[a-zA-Z0-9-]+'), // API keys starting with sk-
    RegExp(r'[a-f0-9]{32,}'), // Long hex strings (potential keys)
  ];

  bool foundSecrets = false;
  final dartFiles = Directory('lib')
      .listSync(recursive: true)
      .where((file) => file.path.endsWith('.dart'))
      .cast<File>();

  for (final file in dartFiles) {
    final content = file.readAsStringSync();
    for (final pattern in secretPatterns) {
      if (pattern.hasMatch(content)) {
        print('   ❌ Potential hardcoded secret found in ${file.path}');
        foundSecrets = true;
        allChecksPassed = false;
      }
    }
  }

  if (!foundSecrets) {
    print('   ✅ No hardcoded secrets detected');
  }

  // Check 4: Verify Android permissions
  print('\n4. Checking Android permissions...');
  final androidManifest = File('android/app/src/main/AndroidManifest.xml');
  if (androidManifest.existsSync()) {
    final manifestContent = androidManifest.readAsStringSync();
    final requiredPermissions = [
      'android.permission.INTERNET',
      'android.permission.CAMERA',
      'android.permission.RECORD_AUDIO',
    ];

    bool allPermissionsPresent = true;
    for (final permission in requiredPermissions) {
      if (manifestContent.contains(permission)) {
        print('   ✅ $permission found');
      } else {
        print('   ❌ $permission missing');
        allPermissionsPresent = false;
        allChecksPassed = false;
      }
    }

    if (allPermissionsPresent) {
      print('   ✅ All required Android permissions present');
    }
  } else {
    print('   ❌ Android manifest not found');
    allChecksPassed = false;
  }

  // Check 5: Verify iOS permissions
  print('\n5. Checking iOS permissions...');
  final iosPlist = File('ios/Runner/Info.plist');
  if (iosPlist.existsSync()) {
    final plistContent = iosPlist.readAsStringSync();
    final requiredPermissions = [
      'NSCameraUsageDescription',
      'NSMicrophoneUsageDescription',
      'NSPhotoLibraryUsageDescription',
    ];

    bool allPermissionsPresent = true;
    for (final permission in requiredPermissions) {
      if (plistContent.contains(permission)) {
        print('   ✅ $permission found');
      } else {
        print('   ❌ $permission missing');
        allPermissionsPresent = false;
        allChecksPassed = false;
      }
    }

    if (allPermissionsPresent) {
      print('   ✅ All required iOS permissions present');
    }
  } else {
    print('   ❌ iOS Info.plist not found');
    allChecksPassed = false;
  }

  // Check 6: Verify environment configuration
  print('\n6. Checking environment configuration...');
  final envFile = File('.env');
  if (envFile.existsSync()) {
    final envContent = envFile.readAsStringSync();
    if (envContent.contains('your-project-id') ||
        envContent.contains('your_supabase_url_here')) {
      print(
        '   ⚠️  .env file contains placeholder values - update with real credentials',
      );
    } else {
      print('   ✅ .env file appears to have real values');
    }
  } else {
    print('   ⚠️  .env file not found - create from .env.example');
  }

  // Final result
  print('\n' + '=' * 50);
  if (allChecksPassed) {
    print('🎉 ALL SECURITY CHECKS PASSED!');
    print('✅ Your app is ready for the next phase of development.');
    exit(0);
  } else {
    print('❌ SECURITY ISSUES FOUND!');
    print('🚨 Please fix the issues above before proceeding.');
    exit(1);
  }
}
