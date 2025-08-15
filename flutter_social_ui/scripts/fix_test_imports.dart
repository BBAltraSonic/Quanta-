#!/usr/bin/env dart

import 'dart:io';

/// Fixes package import references in test files after package rename
void main() async {
  print('🔧 Fixing test import references...');
  
  final testDir = Directory('test');
  if (!await testDir.exists()) {
    print('❌ Test directory not found');
    return;
  }
  
  int filesFixed = 0;
  
  await for (final entity in testDir.list(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      final content = await entity.readAsString();
      
      // Replace flutter_social_ui with quanta in imports
      final newContent = content.replaceAll(
        'package:quanta/',
        'package:quanta/',
      );
      
      if (content != newContent) {
        await entity.writeAsString(newContent);
        filesFixed++;
        print('✅ Fixed: ${entity.path}');
      }
    }
  }
  
  print('');
  print('📋 Summary:');
  print('- Files fixed: $filesFixed');
  print('- Tests should now compile with correct package name');
  print('');
  print('Next step: Run "dart run build_runner build" to generate mocks');
}
