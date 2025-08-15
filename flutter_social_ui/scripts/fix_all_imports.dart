#!/usr/bin/env dart

import 'dart:io';

/// Comprehensive package import fixer for all Dart files
void main() async {
  print('🔧 Fixing all package imports from flutter_social_ui to quanta...');
  
  final projectRoot = Directory('.');
  if (!await projectRoot.exists()) {
    print('❌ Project directory not found');
    return;
  }
  
  int filesFixed = 0;
  int totalFiles = 0;
  
  await for (final entity in projectRoot.list(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      totalFiles++;
      
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
  print('- Total Dart files: $totalFiles');
  print('- Files fixed: $filesFixed');
  print('- Import references updated to use "quanta" package');
  print('');
  
  if (filesFixed > 0) {
    print('✅ All imports fixed! Ready for build.');
  } else {
    print('ℹ️  No imports needed fixing.');
  }
}
