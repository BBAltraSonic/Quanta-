#!/usr/bin/env dart

import 'dart:io';

/// Interactive launch readiness assessment tool
class LaunchReadinessCheck {
  final String projectRoot;
  final List<CheckItem> _checks = [];
  int _passed = 0;
  int _failed = 0;
  int _warnings = 0;
  
  LaunchReadinessCheck(this.projectRoot) {
    _setupChecks();
  }
  
  void _setupChecks() {
    // Security checks
    _checks.add(CheckItem(
      category: 'Security',
      name: 'No hardcoded secrets',
      description: 'Environment variables are properly configured',
      check: () => _checkNoHardcodedSecrets(),
      critical: true,
    ));
    
    _checks.add(CheckItem(
      category: 'Security',
      name: 'Production package identifiers',
      description: 'App uses production-ready package names',
      check: () => _checkProductionPackageNames(),
      critical: true,
    ));
    
    // Configuration checks
    _checks.add(CheckItem(
      category: 'Configuration',
      name: 'Environment configuration exists',
      description: '.env.example file is available for setup',
      check: () => _checkEnvironmentConfig(),
      critical: true,
    ));
    
    _checks.add(CheckItem(
      category: 'Configuration',
      name: 'App branding configured',
      description: 'Web manifest has proper app branding',
      check: () => _checkAppBranding(),
      critical: false,
    ));
    
    // Testing checks
    _checks.add(CheckItem(
      category: 'Testing',
      name: 'Test dependencies installed',
      description: 'Required test packages are available',
      check: () => _checkTestDependencies(),
      critical: true,
    ));
    
    // Build checks
    _checks.add(CheckItem(
      category: 'Build',
      name: 'Flutter build succeeds',
      description: 'App can be built without errors',
      check: () => _checkFlutterBuild(),
      critical: true,
    ));
    
    // Code quality checks
    _checks.add(CheckItem(
      category: 'Quality',
      name: 'No TODO comments in critical files',
      description: 'Production code is complete',
      check: () => _checkNoTodoComments(),
      critical: false,
    ));
  }
  
  Future<void> runChecks() async {
    print('🚀 Quanta Launch Readiness Assessment');
    print('=' * 50);
    print('Project: $projectRoot');
    print('Started: ${DateTime.now()}');
    print('');
    
    for (final check in _checks) {
      await _runCheck(check);
    }
    
    _generateSummary();
  }
  
  Future<void> _runCheck(CheckItem check) async {
    stdout.write('${check.critical ? '🔴' : '⚡'} ${check.name}... ');
    
    try {
      final result = await check.check();
      if (result.passed) {
        print('✅ PASS');
        if (result.details.isNotEmpty) {
          print('   ${result.details}');
        }
        _passed++;
      } else {
        if (check.critical) {
          print('❌ FAIL');
          _failed++;
        } else {
          print('⚠️  WARN');
          _warnings++;
        }
        print('   ${result.details}');
        if (result.recommendation.isNotEmpty) {
          print('   💡 Recommendation: ${result.recommendation}');
        }
      }
    } catch (e) {
      print('❌ ERROR');
      print('   Failed to run check: $e');
      _failed++;
    }
    
    print('');
  }
  
  Future<CheckResult> _checkNoHardcodedSecrets() async {
    final environmentFile = File('$projectRoot/lib/utils/environment.dart');
    if (await environmentFile.exists()) {
      final content = await environmentFile.readAsString();
      
      // Check for JWT patterns in default values
      if (content.contains(RegExp(r'defaultValue:.*eyJ[A-Za-z0-9+/=]'))) {
        return CheckResult(
          false,
          'Hardcoded JWT tokens found in environment.dart',
          'Remove all hardcoded secrets and use environment variables only',
        );
      }
      
      // Check for long hex strings (API keys)
      if (content.contains(RegExp(r'defaultValue:.*[0-9a-f]{32,}'))) {
        return CheckResult(
          false,
          'Hardcoded API keys found in environment.dart',
          'Remove all hardcoded secrets and use environment variables only',
        );
      }
      
      return CheckResult(true, 'No hardcoded secrets detected');
    }
    
    return CheckResult(false, 'Environment configuration file not found');
  }
  
  Future<CheckResult> _checkProductionPackageNames() async {
    final androidBuild = File('$projectRoot/android/app/build.gradle.kts');
    if (await androidBuild.exists()) {
      final content = await androidBuild.readAsString();
      
      if (content.contains('com.example.')) {
        return CheckResult(
          false,
          'Using example package name in Android configuration',
          'Update package name to com.mynkayenzi.quanta or similar',
        );
      }
      
      if (content.contains('com.mynkayenzi.quanta')) {
        return CheckResult(true, 'Production package name configured');
      }
      
      return CheckResult(false, 'Package name needs verification');
    }
    
    return CheckResult(false, 'Android build configuration not found');
  }
  
  Future<CheckResult> _checkEnvironmentConfig() async {
    final envExample = File('$projectRoot/.env.example');
    if (await envExample.exists()) {
      return CheckResult(true, 'Environment configuration template available');
    }
    
    return CheckResult(
      false,
      'Environment configuration template missing',
      'Create .env.example file with required environment variables',
    );
  }
  
  Future<CheckResult> _checkAppBranding() async {
    final webManifest = File('$projectRoot/web/manifest.json');
    if (await webManifest.exists()) {
      final content = await webManifest.readAsString();
      
      if (content.contains('Quanta')) {
        return CheckResult(true, 'App branding configured in web manifest');
      }
      
      if (content.contains('flutter_social_ui')) {
        return CheckResult(
          false,
          'Generic app name in web manifest',
          'Update web manifest with Quanta branding',
        );
      }
      
      return CheckResult(true, 'Web manifest appears to have custom branding');
    }
    
    return CheckResult(false, 'Web manifest not found');
  }
  
  Future<CheckResult> _checkTestDependencies() async {
    final pubspec = File('$projectRoot/pubspec.yaml');
    if (await pubspec.exists()) {
      final content = await pubspec.readAsString();
      
      final hasMockito = content.contains('mockito:');
      final hasIntegrationTest = content.contains('integration_test:');
      final hasBuildRunner = content.contains('build_runner:');
      
      if (hasMockito && hasIntegrationTest && hasBuildRunner) {
        return CheckResult(true, 'All required test dependencies are installed');
      }
      
      final missing = <String>[];
      if (!hasMockito) missing.add('mockito');
      if (!hasIntegrationTest) missing.add('integration_test');
      if (!hasBuildRunner) missing.add('build_runner');
      
      return CheckResult(
        false,
        'Missing test dependencies: ${missing.join(', ')}',
        'Run flutter pub add dev:${missing.join(' dev:')}',
      );
    }
    
    return CheckResult(false, 'pubspec.yaml not found');
  }
  
  Future<CheckResult> _checkFlutterBuild() async {
    // This is a simplified check - in practice you'd want to run actual build
    final mainFile = File('$projectRoot/lib/main.dart');
    final pubspecFile = File('$projectRoot/pubspec.yaml');
    
    if (await mainFile.exists() && await pubspecFile.exists()) {
      return CheckResult(true, 'Core build files present (full build test needed)');
    }
    
    return CheckResult(false, 'Missing core build files');
  }
  
  Future<CheckResult> _checkNoTodoComments() async {
    final criticalFiles = [
      '$projectRoot/lib/services/error_handling_service.dart',
      '$projectRoot/lib/utils/environment.dart',
      '$projectRoot/lib/config/app_config.dart',
    ];
    
    final todoFiles = <String>[];
    
    for (final filePath in criticalFiles) {
      final file = File(filePath);
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.toLowerCase().contains('todo')) {
          todoFiles.add(filePath.replaceAll('$projectRoot/', ''));
        }
      }
    }
    
    if (todoFiles.isEmpty) {
      return CheckResult(true, 'No TODO comments in critical files');
    }
    
    return CheckResult(
      false,
      'TODO comments found in: ${todoFiles.join(', ')}',
      'Complete or remove TODO comments before launch',
    );
  }
  
  void _generateSummary() {
    print('📊 LAUNCH READINESS SUMMARY');
    print('=' * 50);
    print('✅ Passed: $_passed');
    print('❌ Failed: $_failed');
    print('⚠️  Warnings: $_warnings');
    print('');
    
    final total = _passed + _failed + _warnings;
    final score = ((_passed + (_warnings * 0.5)) / total * 100).round();
    
    print('📈 Overall Score: $score%');
    print('');
    
    if (_failed == 0 && score >= 90) {
      print('🎉 LAUNCH READY!');
      print('Your app meets the minimum requirements for launch.');
      print('Address any warnings for optimal production deployment.');
    } else if (_failed == 0) {
      print('⚡ LAUNCH CAUTION');
      print('App is functional but has warnings that should be addressed.');
    } else {
      print('🚫 LAUNCH BLOCKED');
      print('Critical issues must be resolved before launch.');
    }
    
    print('');
    print('Next Steps:');
    if (_failed > 0) {
      print('1. Fix all failed critical checks');
      print('2. Re-run this assessment');
    }
    if (_warnings > 0) {
      print('• Address warning items for optimal launch');
    }
    print('• Run security audit with: dart scripts/security_scanner.dart');
    print('• Test thoroughly in staging environment');
  }
}

class CheckItem {
  final String category;
  final String name;
  final String description;
  final Future<CheckResult> Function() check;
  final bool critical;
  
  CheckItem({
    required this.category,
    required this.name,
    required this.description,
    required this.check,
    required this.critical,
  });
}

class CheckResult {
  final bool passed;
  final String details;
  final String recommendation;
  
  CheckResult(this.passed, this.details, [this.recommendation = '']);
}

void main(List<String> args) async {
  final projectRoot = args.isNotEmpty ? args[0] : '.';
  final checker = LaunchReadinessCheck(projectRoot);
  await checker.runChecks();
}
