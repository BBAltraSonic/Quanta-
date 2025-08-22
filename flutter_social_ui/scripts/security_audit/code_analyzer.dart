#!/usr/bin/env dart

/// Quanta Security Audit - Static Code Security Analysis
/// 
/// This script performs static analysis of the Dart/Flutter codebase to identify
/// potential security vulnerabilities, coding issues, and security anti-patterns.
/// 
/// Usage: dart scripts/security_audit/code_analyzer.dart
/// 
/// Features:
/// - Scans for hardcoded secrets and credentials
/// - Identifies insecure coding patterns
/// - Checks for potential injection vulnerabilities
/// - Validates security configurations
/// - Generates detailed security analysis reports

import 'dart:io';
import 'dart:convert';

class CodeSecurityAnalyzer {
  final List<SecurityFinding> _findings = [];
  final Map<String, int> _riskCategories = {};
  
  static const List<String> _excludedDirectories = [
    '.dart_tool',
    'build',
    '.git',
    'node_modules',
    '.idea',
    '.vscode',
  ];

  /// Main entry point for code security analysis
  Future<CodeSecurityReport> analyzeCodebase() async {
    print('🔍 Starting static code security analysis...\n');
    
    final projectDir = Directory.current;
    await _scanDirectory(projectDir);
    
    final report = _generateReport();
    await _saveReport(report);
    
    return report;
  }

  /// Recursively scan directory for security issues
  Future<void> _scanDirectory(Directory dir) async {
    await for (final entity in dir.list()) {
      if (entity is Directory) {
        final dirName = entity.path.split(Platform.pathSeparator).last;
        if (!_excludedDirectories.contains(dirName)) {
          await _scanDirectory(entity);
        }
      } else if (entity is File) {
        await _scanFile(entity);
      }
    }
  }

  /// Scan individual file for security issues
  Future<void> _scanFile(File file) async {
    final extension = file.path.split('.').last.toLowerCase();
    
    // Only scan relevant file types
    if (!['dart', 'yaml', 'json', 'xml', 'gradle', 'swift', 'kt'].contains(extension)) {
      return;
    }

    try {
      final content = await file.readAsString();
      final lines = content.split('\n');
      
      print('🔎 Scanning: ${file.path}');
      
      // Run security checks
      await _checkHardcodedSecrets(file, content, lines);
      await _checkInsecurePatterns(file, content, lines);
      await _checkConfigurationSecurity(file, content, lines);
      await _checkDataValidation(file, content, lines);
      await _checkNetworkSecurity(file, content, lines);
      await _checkAuthenticationSecurity(file, content, lines);
      await _checkFileSystemSecurity(file, content, lines);
      
    } catch (e) {
      _addFinding(SecurityFinding(
        type: SecurityFindingType.error,
        severity: SecuritySeverity.low,
        file: file.path,
        line: 0,
        description: 'Could not read file for analysis: $e',
        recommendation: 'Ensure file is readable and properly encoded',
        category: 'File Access',
      ));
    }
  }

  /// Check for hardcoded secrets and credentials
  Future<void> _checkHardcodedSecrets(File file, String content, List<String> lines) async {
    final secretPatterns = [
      // API Keys
      RegExp(r'api[_-]?key\s*[=:]\s*["\']([a-zA-Z0-9\-_]{20,})["\']', caseSensitive: false),
      RegExp(r'secret[_-]?key\s*[=:]\s*["\']([a-zA-Z0-9\-_]{20,})["\']', caseSensitive: false),
      RegExp(r'access[_-]?token\s*[=:]\s*["\']([a-zA-Z0-9\-_]{20,})["\']', caseSensitive: false),
      
      // Database URLs
      RegExp(r'postgres://[^"\'\\s]+', caseSensitive: false),
      RegExp(r'mysql://[^"\'\\s]+', caseSensitive: false),
      RegExp(r'mongodb://[^"\'\\s]+', caseSensitive: false),
      
      // Firebase/Supabase URLs (specific patterns)
      RegExp(r'https://[a-zA-Z0-9\-]+\.supabase\.co'),
      RegExp(r'https://[a-zA-Z0-9\-]+\.firebaseio\.com'),
      
      // Private keys
      RegExp(r'-----BEGIN\s+(RSA\s+)?PRIVATE\s+KEY-----'),
      RegExp(r'-----BEGIN\s+OPENSSH\s+PRIVATE\s+KEY-----'),
      
      // JWT Tokens
      RegExp(r'eyJ[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]*'),
      
      // Generic high-entropy strings
      RegExp(r'["\'][A-Za-z0-9\+/]{40,}={0,2}["\']'), // Base64
    ];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      
      for (final pattern in secretPatterns) {
        final matches = pattern.allMatches(line);
        for (final match in matches) {
          // Skip if this looks like a template or example
          if (_isLikelyTemplate(line)) continue;
          
          _addFinding(SecurityFinding(
            type: SecurityFindingType.hardcodedSecret,
            severity: SecuritySeverity.critical,
            file: file.path,
            line: i + 1,
            column: match.start,
            description: 'Potential hardcoded secret or credential detected',
            evidence: match.group(0) ?? '',
            recommendation: 'Move secrets to environment variables or secure configuration',
            category: 'Secrets Management',
            cweId: 'CWE-798',
          ));
        }
      }
    }
  }

  /// Check for insecure coding patterns
  Future<void> _checkInsecurePatterns(File file, String content, List<String> lines) async {
    final insecurePatterns = [
      // SQL Injection potential
      InsecurePattern(
        pattern: RegExp(r'query\s*\(\s*["\'].*\$\{.*\}.*["\']', caseSensitive: false),
        severity: SecuritySeverity.high,
        description: 'Potential SQL injection vulnerability - string interpolation in query',
        recommendation: 'Use parameterized queries or prepared statements',
        category: 'Injection',
        cweId: 'CWE-89',
      ),
      
      // XSS potential
      InsecurePattern(
        pattern: RegExp(r'innerHTML\s*=\s*.*\$\{.*\}', caseSensitive: false),
        severity: SecuritySeverity.high,
        description: 'Potential XSS vulnerability - unescaped user input in HTML',
        recommendation: 'Sanitize user input before inserting into HTML',
        category: 'Cross-Site Scripting',
        cweId: 'CWE-79',
      ),
      
      // Weak randomness
      InsecurePattern(
        pattern: RegExp(r'Random\(\)\.(nextInt|nextDouble)\s*\(', caseSensitive: false),
        severity: SecuritySeverity.medium,
        description: 'Using weak random number generation for security purposes',
        recommendation: 'Use cryptographically secure random number generation',
        category: 'Cryptography',
        cweId: 'CWE-338',
      ),
      
      // Debug/development code
      InsecurePattern(
        pattern: RegExp(r'print\s*\(.*password.*\)', caseSensitive: false),
        severity: SecuritySeverity.medium,
        description: 'Potential sensitive data logging',
        recommendation: 'Remove debug logging of sensitive information',
        category: 'Information Disclosure',
        cweId: 'CWE-532',
      ),
      
      // Insecure HTTP usage
      InsecurePattern(
        pattern: RegExp(r'http://[^"\'\\s]+', caseSensitive: false),
        severity: SecuritySeverity.medium,
        description: 'Using insecure HTTP protocol',
        recommendation: 'Use HTTPS for all network communications',
        category: 'Network Security',
        cweId: 'CWE-319',
      ),
      
      // Trust all certificates (dangerous)
      InsecurePattern(
        pattern: RegExp(r'badCertificateCallback.*true', caseSensitive: false),
        severity: SecuritySeverity.high,
        description: 'Accepting all SSL certificates (dangerous)',
        recommendation: 'Implement proper certificate validation',
        category: 'Network Security',
        cweId: 'CWE-295',
      ),
    ];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      
      for (final insecurePattern in insecurePatterns) {
        final matches = insecurePattern.pattern.allMatches(line);
        for (final match in matches) {
          _addFinding(SecurityFinding(
            type: SecurityFindingType.insecurePattern,
            severity: insecurePattern.severity,
            file: file.path,
            line: i + 1,
            column: match.start,
            description: insecurePattern.description,
            evidence: match.group(0) ?? '',
            recommendation: insecurePattern.recommendation,
            category: insecurePattern.category,
            cweId: insecurePattern.cweId,
          ));
        }
      }
    }
  }

  /// Check configuration security
  Future<void> _checkConfigurationSecurity(File file, String content, List<String> lines) async {
    final fileName = file.path.split(Platform.pathSeparator).last;
    
    // Android security checks
    if (fileName == 'AndroidManifest.xml') {
      await _checkAndroidSecurity(file, content, lines);
    }
    
    // iOS security checks
    if (fileName == 'Info.plist') {
      await _checkiOSSecurity(file, content, lines);
    }
    
    // Network security config
    if (fileName == 'network_security_config.xml') {
      await _checkNetworkSecurityConfig(file, content, lines);
    }
    
    // Pubspec security
    if (fileName == 'pubspec.yaml') {
      await _checkPubspecSecurity(file, content, lines);
    }
  }

  /// Check Android-specific security configurations
  Future<void> _checkAndroidSecurity(File file, String content, List<String> lines) async {
    // Check for dangerous permissions
    final dangerousPermissions = [
      'android.permission.WRITE_EXTERNAL_STORAGE',
      'android.permission.READ_EXTERNAL_STORAGE',
      'android.permission.CAMERA',
      'android.permission.RECORD_AUDIO',
      'android.permission.ACCESS_FINE_LOCATION',
      'android.permission.READ_CONTACTS',
      'android.permission.READ_SMS',
    ];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      
      for (final permission in dangerousPermissions) {
        if (line.contains(permission)) {
          _addFinding(SecurityFinding(
            type: SecurityFindingType.configuration,
            severity: SecuritySeverity.medium,
            file: file.path,
            line: i + 1,
            description: 'Dangerous permission declared: $permission',
            evidence: line.trim(),
            recommendation: 'Ensure this permission is necessary and properly justified',
            category: 'Permissions',
          ));
        }
      }
      
      // Check for debug mode
      if (line.contains('android:debuggable="true"')) {
        _addFinding(SecurityFinding(
          type: SecurityFindingType.configuration,
          severity: SecuritySeverity.high,
          file: file.path,
          line: i + 1,
          description: 'Debug mode enabled in production manifest',
          evidence: line.trim(),
          recommendation: 'Disable debug mode for production builds',
          category: 'Debug Configuration',
          cweId: 'CWE-489',
        ));
      }
      
      // Check for clear text traffic
      if (line.contains('android:usesCleartextTraffic="true"')) {
        _addFinding(SecurityFinding(
          type: SecurityFindingType.configuration,
          severity: SecuritySeverity.high,
          file: file.path,
          line: i + 1,
          description: 'Clear text traffic allowed',
          evidence: line.trim(),
          recommendation: 'Disable clear text traffic for production',
          category: 'Network Security',
          cweId: 'CWE-319',
        ));
      }
    }
  }

  /// Check iOS-specific security configurations
  Future<void> _checkiOSSecurity(File file, String content, List<String> lines) async {
    // Check for ATS (App Transport Security) bypass
    if (content.contains('NSAllowsArbitraryLoads') && content.contains('<true/>')) {
      _addFinding(SecurityFinding(
        type: SecurityFindingType.configuration,
        severity: SecuritySeverity.high,
        file: file.path,
        line: 0,
        description: 'App Transport Security disabled',
        recommendation: 'Enable ATS and use HTTPS for all network communications',
        category: 'Network Security',
        cweId: 'CWE-319',
      ));
    }
  }

  /// Check network security configuration
  Future<void> _checkNetworkSecurityConfig(File file, String content, List<String> lines) async {
    if (content.contains('cleartextTrafficPermitted="true"')) {
      _addFinding(SecurityFinding(
        type: SecurityFindingType.configuration,
        severity: SecuritySeverity.high,
        file: file.path,
        line: 0,
        description: 'Clear text traffic permitted in network security config',
        recommendation: 'Disable clear text traffic for production',
        category: 'Network Security',
        cweId: 'CWE-319',
      ));
    }
  }

  /// Check pubspec.yaml for security issues
  Future<void> _checkPubspecSecurity(File file, String content, List<String> lines) async {
    // Check for git dependencies (potential supply chain risk)
    final gitDependencyPattern = RegExp(r'git:\s*https?://github\.com/[^/]+/[^/\s]+');
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (gitDependencyPattern.hasMatch(line)) {
        _addFinding(SecurityFinding(
          type: SecurityFindingType.configuration,
          severity: SecuritySeverity.medium,
          file: file.path,
          line: i + 1,
          description: 'Git dependency detected - potential supply chain risk',
          evidence: line.trim(),
          recommendation: 'Use pub.dev packages when possible, review git dependencies carefully',
          category: 'Supply Chain',
          cweId: 'CWE-829',
        ));
      }
    }
  }

  /// Check data validation patterns
  Future<void> _checkDataValidation(File file, String content, List<String> lines) async {
    final validationPatterns = [
      // Missing input validation
      InsecurePattern(
        pattern: RegExp(r'TextEditingController\(\).*\.text', caseSensitive: false),
        severity: SecuritySeverity.low,
        description: 'User input without validation',
        recommendation: 'Implement input validation and sanitization',
        category: 'Input Validation',
        cweId: 'CWE-20',
      ),
    ];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      
      for (final pattern in validationPatterns) {
        if (pattern.pattern.hasMatch(line)) {
          _addFinding(SecurityFinding(
            type: SecurityFindingType.validation,
            severity: pattern.severity,
            file: file.path,
            line: i + 1,
            description: pattern.description,
            evidence: line.trim(),
            recommendation: pattern.recommendation,
            category: pattern.category,
            cweId: pattern.cweId,
          ));
        }
      }
    }
  }

  /// Check network security patterns
  Future<void> _checkNetworkSecurity(File file, String content, List<String> lines) async {
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      
      // Check for HTTP client without timeout
      if (line.contains('http.Client()') && !content.contains('timeout')) {
        _addFinding(SecurityFinding(
          type: SecurityFindingType.configuration,
          severity: SecuritySeverity.medium,
          file: file.path,
          line: i + 1,
          description: 'HTTP client without timeout configuration',
          evidence: line.trim(),
          recommendation: 'Configure appropriate timeouts for HTTP clients',
          category: 'Network Security',
        ));
      }
    }
  }

  /// Check authentication security patterns
  Future<void> _checkAuthenticationSecurity(File file, String content, List<String> lines) async {
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      
      // Check for weak password validation
      if (line.contains('password') && line.contains('length') && line.contains('< 6')) {
        _addFinding(SecurityFinding(
          type: SecurityFindingType.authentication,
          severity: SecuritySeverity.medium,
          file: file.path,
          line: i + 1,
          description: 'Weak password length requirement',
          evidence: line.trim(),
          recommendation: 'Enforce stronger password requirements (minimum 8-12 characters)',
          category: 'Authentication',
          cweId: 'CWE-521',
        ));
      }
    }
  }

  /// Check file system security patterns
  Future<void> _checkFileSystemSecurity(File file, String content, List<String> lines) async {
    final fileSecurityPatterns = [
      // Path traversal potential
      InsecurePattern(
        pattern: RegExp(r'File\s*\(\s*["\'][^"\']*\.\./.*["\']', caseSensitive: false),
        severity: SecuritySeverity.high,
        description: 'Potential path traversal vulnerability',
        recommendation: 'Validate and sanitize file paths',
        category: 'Path Traversal',
        cweId: 'CWE-22',
      ),
    ];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      
      for (final pattern in fileSecurityPatterns) {
        if (pattern.pattern.hasMatch(line)) {
          _addFinding(SecurityFinding(
            type: SecurityFindingType.fileSystem,
            severity: pattern.severity,
            file: file.path,
            line: i + 1,
            description: pattern.description,
            evidence: line.trim(),
            recommendation: pattern.recommendation,
            category: pattern.category,
            cweId: pattern.cweId,
          ));
        }
      }
    }
  }

  /// Check if a line looks like a template or placeholder
  bool _isLikelyTemplate(String line) {
    final templateIndicators = [
      'your_',
      'YOUR_',
      'example',
      'EXAMPLE',
      'placeholder',
      'PLACEHOLDER',
      'xxx',
      'XXX',
      '...',
      'template',
      'TEMPLATE',
    ];

    return templateIndicators.any((indicator) => line.contains(indicator));
  }

  /// Add finding to results
  void _addFinding(SecurityFinding finding) {
    _findings.add(finding);
    _riskCategories[finding.category] = (_riskCategories[finding.category] ?? 0) + 1;
  }

  /// Generate comprehensive security report
  CodeSecurityReport _generateReport() {
    final criticalFindings = _findings.where((f) => f.severity == SecuritySeverity.critical).toList();
    final highFindings = _findings.where((f) => f.severity == SecuritySeverity.high).toList();
    final mediumFindings = _findings.where((f) => f.severity == SecuritySeverity.medium).toList();
    final lowFindings = _findings.where((f) => f.severity == SecuritySeverity.low).toList();

    print('\n📋 Static Code Analysis Summary:');
    print('   🔴 Critical: ${criticalFindings.length}');
    print('   🟠 High: ${highFindings.length}');
    print('   🟡 Medium: ${mediumFindings.length}');
    print('   🟢 Low: ${lowFindings.length}');
    print('   📊 Total Findings: ${_findings.length}');

    // Print top risk categories
    if (_riskCategories.isNotEmpty) {
      print('\n📊 Top Risk Categories:');
      final sortedCategories = _riskCategories.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      for (int i = 0; i < 5 && i < sortedCategories.length; i++) {
        final entry = sortedCategories[i];
        print('   ${i + 1}. ${entry.key}: ${entry.value} issues');
      }
    }

    final report = CodeSecurityReport(
      scanDate: DateTime.now(),
      totalFiles: _findings.map((f) => f.file).toSet().length,
      totalFindings: _findings.length,
      criticalFindings: criticalFindings.length,
      highFindings: highFindings.length,
      mediumFindings: mediumFindings.length,
      lowFindings: lowFindings.length,
      findings: _findings,
      riskCategories: _riskCategories,
      recommendations: _generateRecommendations(),
    );

    return report;
  }

  /// Generate actionable recommendations
  List<String> _generateRecommendations() {
    final recommendations = <String>[];
    
    if (_findings.any((f) => f.type == SecurityFindingType.hardcodedSecret)) {
      recommendations.add('🔑 Move all hardcoded secrets to environment variables');
    }
    
    if (_findings.any((f) => f.category == 'Network Security')) {
      recommendations.add('🌐 Implement HTTPS-only communication');
    }
    
    if (_findings.any((f) => f.category == 'Input Validation')) {
      recommendations.add('✅ Implement comprehensive input validation');
    }
    
    if (_findings.any((f) => f.category == 'Authentication')) {
      recommendations.add('🔐 Strengthen authentication mechanisms');
    }
    
    if (_findings.any((f) => f.category == 'Permissions')) {
      recommendations.add('🛡️ Review and minimize app permissions');
    }
    
    recommendations.add('🔄 Integrate static analysis into CI/CD pipeline');
    recommendations.add('📚 Provide security training for development team');
    recommendations.add('🔍 Conduct regular security code reviews');
    
    return recommendations;
  }

  /// Save report to file
  Future<void> _saveReport(CodeSecurityReport report) async {
    final reportsDir = Directory('reports/security');
    if (!reportsDir.existsSync()) {
      reportsDir.createSync(recursive: true);
    }
    
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final reportFile = File('reports/security/code_analysis_$timestamp.json');
    
    await reportFile.writeAsString(jsonEncode(report.toJson()));
    
    print('\n💾 Report saved to: ${reportFile.path}');
    print('📄 View detailed report at: ${reportFile.absolute.path}');
  }
}

/// Pattern for insecure code detection
class InsecurePattern {
  final RegExp pattern;
  final SecuritySeverity severity;
  final String description;
  final String recommendation;
  final String category;
  final String? cweId;

  InsecurePattern({
    required this.pattern,
    required this.severity,
    required this.description,
    required this.recommendation,
    required this.category,
    this.cweId,
  });
}

/// Security finding from static analysis
class SecurityFinding {
  final SecurityFindingType type;
  final SecuritySeverity severity;
  final String file;
  final int line;
  final int? column;
  final String description;
  final String? evidence;
  final String recommendation;
  final String category;
  final String? cweId;

  SecurityFinding({
    required this.type,
    required this.severity,
    required this.file,
    required this.line,
    this.column,
    required this.description,
    this.evidence,
    required this.recommendation,
    required this.category,
    this.cweId,
  });

  Map<String, dynamic> toJson() => {
    'type': type.toString(),
    'severity': severity.toString(),
    'file': file,
    'line': line,
    'column': column,
    'description': description,
    'evidence': evidence,
    'recommendation': recommendation,
    'category': category,
    'cweId': cweId,
  };
}

/// Types of security findings
enum SecurityFindingType {
  hardcodedSecret,
  insecurePattern,
  configuration,
  validation,
  authentication,
  fileSystem,
  error,
}

/// Security severity levels
enum SecuritySeverity {
  critical,
  high,
  medium,
  low,
}

/// Complete code security analysis report
class CodeSecurityReport {
  final DateTime scanDate;
  final int totalFiles;
  final int totalFindings;
  final int criticalFindings;
  final int highFindings;
  final int mediumFindings;
  final int lowFindings;
  final List<SecurityFinding> findings;
  final Map<String, int> riskCategories;
  final List<String> recommendations;

  CodeSecurityReport({
    required this.scanDate,
    required this.totalFiles,
    required this.totalFindings,
    required this.criticalFindings,
    required this.highFindings,
    required this.mediumFindings,
    required this.lowFindings,
    required this.findings,
    required this.riskCategories,
    required this.recommendations,
  });

  Map<String, dynamic> toJson() => {
    'scanDate': scanDate.toIso8601String(),
    'totalFiles': totalFiles,
    'totalFindings': totalFindings,
    'criticalFindings': criticalFindings,
    'highFindings': highFindings,
    'mediumFindings': mediumFindings,
    'lowFindings': lowFindings,
    'findings': findings.map((f) => f.toJson()).toList(),
    'riskCategories': riskCategories,
    'recommendations': recommendations,
  };
}

/// Main function to run code security analysis
Future<void> main() async {
  try {
    final analyzer = CodeSecurityAnalyzer();
    final report = await analyzer.analyzeCodebase();
    
    print('\n✅ Code security analysis completed successfully!');
    
    if (report.criticalFindings > 0 || report.highFindings > 0) {
      print('\n⚠️ Security issues found that require attention!');
      exit(1);
    }
    
    exit(0);
  } catch (e) {
    print('\n❌ Code security analysis failed: $e');
    exit(1);
  }
}