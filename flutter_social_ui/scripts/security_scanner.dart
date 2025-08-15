#!/usr/bin/env dart

import 'dart:io';
import 'dart:convert';

/// Security vulnerability scanner for Flutter Social UI project
class SecurityScanner {
  final String projectRoot;
  final List<SecurityIssue> issues = [];
  
  SecurityScanner(this.projectRoot);

  /// Main scan entry point
  Future<void> runScan() async {
    print('🔒 Flutter Social UI - Security Audit Scanner');
    print('=' * 50);
    print('Project: $projectRoot');
    print('Scan started: ${DateTime.now()}');
    print('');
    
    await _scanForHardcodedSecrets();
    await _scanForInsecureConfigurations();
    await _scanForProductionReadiness();
    await _scanForDependencyVulnerabilities();
    
    _generateReport();
  }

  /// Scan for hardcoded API keys and secrets
  Future<void> _scanForHardcodedSecrets() async {
    print('🔍 Scanning for hardcoded secrets...');
    
    final patterns = [
      RegExp(r'defaultValue:.*eyJ[A-Za-z0-9+/=]*'), // API keys with defaultValue
      RegExp(r'SUPABASE_.*eyJ[A-Za-z0-9+/=]*'), // Supabase keys
      RegExp(r'eyJ[A-Za-z0-9+/=]*\.[A-Za-z0-9+/=]*'), // JWT tokens
      RegExp(r'sk-[A-Za-z0-9]{40,}'), // OpenAI style keys
      RegExp(r'[0-9a-f]{32,}'), // Generic long hex strings
    ];
    
    await _scanDirectory(Directory('$projectRoot/lib'), patterns, 'HARDCODED_SECRET');
    await _scanDirectory(Directory('$projectRoot/android'), patterns, 'HARDCODED_SECRET');
    await _scanDirectory(Directory('$projectRoot/ios'), patterns, 'HARDCODED_SECRET');
  }

  /// Scan for insecure configurations
  Future<void> _scanForInsecureConfigurations() async {
    print('⚙️ Scanning for insecure configurations...');
    
    // Check Android build config
    final androidBuildFile = File('$projectRoot/android/app/build.gradle.kts');
    if (await androidBuildFile.exists()) {
      final content = await androidBuildFile.readAsString();
      
      if (content.contains('com.example.')) {
        issues.add(SecurityIssue(
          type: 'INSECURE_CONFIG',
          severity: 'CRITICAL',
          file: 'android/app/build.gradle.kts',
          message: 'Using example package name in production build',
          line: _findLineNumber(content, 'com.example.'),
        ));
      }
      
      if (content.contains('signingConfig signingConfigs.debug')) {
        issues.add(SecurityIssue(
          type: 'INSECURE_CONFIG',
          severity: 'HIGH',
          file: 'android/app/build.gradle.kts',
          message: 'Using debug signing config for release builds',
          line: _findLineNumber(content, 'signingConfig signingConfigs.debug'),
        ));
      }
    }
    
    // Check iOS configuration
    final iosPlistFile = File('$projectRoot/ios/Runner/Info.plist');
    if (await iosPlistFile.exists()) {
      final content = await iosPlistFile.readAsString();
      if (content.contains('<string>flutter_social_ui</string>')) {
        issues.add(SecurityIssue(
          type: 'INSECURE_CONFIG',
          severity: 'MEDIUM',
          file: 'ios/Runner/Info.plist',
          message: 'Generic app name in iOS configuration',
          line: _findLineNumber(content, 'flutter_social_ui'),
        ));
      }
    }
  }

  /// Check production readiness
  Future<void> _scanForProductionReadiness() async {
    print('🚀 Scanning production readiness...');
    
    // Check web manifest
    final webManifest = File('$projectRoot/web/manifest.json');
    if (await webManifest.exists()) {
      final content = await webManifest.readAsString();
      final manifest = jsonDecode(content);
      
      if (manifest['name']?.contains('flutter_social_ui') == true) {
        issues.add(SecurityIssue(
          type: 'PROD_READINESS',
          severity: 'HIGH',
          file: 'web/manifest.json',
          message: 'Generic app name in web manifest',
          line: 2,
        ));
      }
    }
    
    // Check for TODO comments in critical files
    final criticalFiles = [
      '$projectRoot/lib/services/auth_service.dart',
      '$projectRoot/lib/services/error_handling_service.dart',
      '$projectRoot/lib/utils/environment.dart',
    ];
    
    for (final filePath in criticalFiles) {
      final file = File(filePath);
      if (await file.exists()) {
        final content = await file.readAsString();
        final lines = content.split('\n');
        
        for (int i = 0; i < lines.length; i++) {
          if (lines[i].toLowerCase().contains('todo')) {
            issues.add(SecurityIssue(
              type: 'PROD_READINESS',
              severity: 'MEDIUM',
              file: filePath.replaceAll('$projectRoot/', ''),
              message: 'TODO comment found in critical file',
              line: i + 1,
              context: lines[i].trim(),
            ));
          }
        }
      }
    }
  }

  /// Scan for dependency vulnerabilities
  Future<void> _scanForDependencyVulnerabilities() async {
    print('📦 Scanning dependencies...');
    
    final pubspecFile = File('$projectRoot/pubspec.yaml');
    if (await pubspecFile.exists()) {
      final content = await pubspecFile.readAsString();
      
      // Check for missing test dependencies
      if (!content.contains('mockito:')) {
        issues.add(SecurityIssue(
          type: 'DEPENDENCY',
          severity: 'HIGH',
          file: 'pubspec.yaml',
          message: 'Missing mockito dependency for testing',
          line: 1,
        ));
      }
      
      if (!content.contains('integration_test:')) {
        issues.add(SecurityIssue(
          type: 'DEPENDENCY',
          severity: 'MEDIUM',
          file: 'pubspec.yaml',
          message: 'Missing integration_test dependency',
          line: 1,
        ));
      }
    }
  }

  /// Scan directory for patterns
  Future<void> _scanDirectory(Directory dir, List<RegExp> patterns, String issueType) async {
    if (!await dir.exists()) return;
    
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        await _scanFile(entity, patterns, issueType);
      }
    }
  }

  /// Scan individual file
  Future<void> _scanFile(File file, List<RegExp> patterns, String issueType) async {
    final content = await file.readAsString();
    final lines = content.split('\n');
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      for (final pattern in patterns) {
        final matches = pattern.allMatches(line);
        for (final match in matches) {
          issues.add(SecurityIssue(
            type: issueType,
            severity: 'CRITICAL',
            file: file.path.replaceAll('$projectRoot/', ''),
            message: 'Potential hardcoded secret detected',
            line: i + 1,
            context: line.trim(),
            evidence: match.group(0),
          ));
        }
      }
    }
  }

  /// Find line number for a string in content
  int _findLineNumber(String content, String searchString) {
    final lines = content.split('\n');
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].contains(searchString)) {
        return i + 1;
      }
    }
    return 1;
  }

  /// Generate security report
  void _generateReport() {
    print('\n📊 SECURITY AUDIT RESULTS');
    print('=' * 50);
    
    final critical = issues.where((i) => i.severity == 'CRITICAL').length;
    final high = issues.where((i) => i.severity == 'HIGH').length;
    final medium = issues.where((i) => i.severity == 'MEDIUM').length;
    
    print('Total Issues Found: ${issues.length}');
    print('🔴 Critical: $critical');
    print('🟠 High: $high');
    print('🟡 Medium: $medium');
    print('');
    
    if (issues.isEmpty) {
      print('✅ No security issues detected!');
      return;
    }
    
    // Group by severity
    final groupedIssues = <String, List<SecurityIssue>>{};
    for (final issue in issues) {
      groupedIssues.putIfAbsent(issue.severity, () => []).add(issue);
    }
    
    for (final severity in ['CRITICAL', 'HIGH', 'MEDIUM']) {
      final severityIssues = groupedIssues[severity] ?? [];
      if (severityIssues.isEmpty) continue;
      
      print('${_getSeverityIcon(severity)} $severity ISSUES (${severityIssues.length})');
      print('-' * 30);
      
      for (final issue in severityIssues) {
        print('📁 ${issue.file}:${issue.line}');
        print('   ${issue.message}');
        if (issue.context != null) {
          print('   Context: ${issue.context}');
        }
        if (issue.evidence != null) {
          print('   Evidence: ${issue.evidence}');
        }
        print('');
      }
    }
    
    // Generate recommendations
    print('🔧 RECOMMENDATIONS');
    print('-' * 30);
    if (critical > 0) {
      print('❌ LAUNCH BLOCKED - Critical security issues must be resolved');
      print('1. Remove all hardcoded API keys and secrets');
      print('2. Implement environment-based configuration');
      print('3. Rotate any exposed API keys immediately');
    } else if (high > 0) {
      print('⚠️ LAUNCH CAUTION - High priority fixes needed');
      print('1. Fix insecure configurations before production');
      print('2. Update package identifiers and signing configs');
    } else {
      print('✅ Security scan passed - Minor issues can be addressed post-launch');
    }
    
    // Save report to file
    _saveReportToFile();
  }

  /// Save report to file
  void _saveReportToFile() {
    final report = StringBuffer();
    report.writeln('# Security Audit Report');
    report.writeln('Generated: ${DateTime.now()}');
    report.writeln('Project: Flutter Social UI');
    report.writeln('');
    
    report.writeln('## Summary');
    report.writeln('- Total Issues: ${issues.length}');
    report.writeln('- Critical: ${issues.where((i) => i.severity == 'CRITICAL').length}');
    report.writeln('- High: ${issues.where((i) => i.severity == 'HIGH').length}');
    report.writeln('- Medium: ${issues.where((i) => i.severity == 'MEDIUM').length}');
    report.writeln('');
    
    report.writeln('## Issues');
    for (final issue in issues) {
      report.writeln('### ${issue.severity} - ${issue.file}:${issue.line}');
      report.writeln('**Type:** ${issue.type}');
      report.writeln('**Message:** ${issue.message}');
      if (issue.context != null) report.writeln('**Context:** `${issue.context}`');
      if (issue.evidence != null) report.writeln('**Evidence:** `${issue.evidence}`');
      report.writeln('');
    }
    
    File('$projectRoot/security_audit_report.md').writeAsStringSync(report.toString());
    print('📄 Report saved to: security_audit_report.md');
  }

  String _getSeverityIcon(String severity) {
    switch (severity) {
      case 'CRITICAL': return '🔴';
      case 'HIGH': return '🟠';
      case 'MEDIUM': return '🟡';
      default: return '⚪';
    }
  }
}

class SecurityIssue {
  final String type;
  final String severity;
  final String file;
  final String message;
  final int line;
  final String? context;
  final String? evidence;
  
  SecurityIssue({
    required this.type,
    required this.severity,
    required this.file,
    required this.message,
    required this.line,
    this.context,
    this.evidence,
  });
}

void main(List<String> args) async {
  final projectRoot = args.isNotEmpty ? args[0] : '.';
  final scanner = SecurityScanner(projectRoot);
  await scanner.runScan();
}
