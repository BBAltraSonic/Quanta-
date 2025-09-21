#!/usr/bin/env dart

/// Quanta Security Audit - Static Code Security Analysis
///
/// This script performs static analysis of the Dart/Flutter codebase to identify
/// potential security vulnerabilities, coding issues, and security anti-patterns.

import 'dart:io';
import 'dart:convert';
import 'logger.dart';

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
    SecurityLogger.info('🔍 Starting static code security analysis...');

    final projectDir = Directory.current;
    await _scanDirectory(projectDir);

    final report = _generateReport();
    await _saveReport(report);

    return report;
  }

  /// Recursively scan directory for security issues
  Future<void> _scanDirectory(Directory dir) async {
    try {
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
    } catch (e) {
      SecurityLogger.warning('Could not scan directory ${dir.path}: $e');
    }
  }

  /// Scan individual file for security issues
  Future<void> _scanFile(File file) async {
    final extension = file.path.split('.').last.toLowerCase();

    // Only scan relevant file types
    if (![
      'dart',
      'yaml',
      'json',
      'xml',
      'gradle',
      'swift',
      'kt',
    ].contains(extension)) {
      return;
    }

    try {
      final content = await file.readAsString();
      final lines = content.split('\n');

      SecurityLogger.debug('🔎 Scanning: ${file.path}');

      // Run security checks
      await _checkHardcodedSecrets(file, content, lines);
      await _checkInsecurePatterns(file, content, lines);
      await _checkConfigurationSecurity(file, content, lines);
    } catch (e) {
      _addFinding(
        SecurityFinding(
          type: SecurityFindingType.error,
          severity: SecuritySeverity.low,
          file: file.path,
          line: 0,
          description: 'Could not read file for analysis: $e',
          recommendation: 'Ensure file is readable and properly encoded',
          category: 'File Access',
        ),
      );
    }
  }

  /// Check for hardcoded secrets and credentials
  Future<void> _checkHardcodedSecrets(
    File file,
    String content,
    List<String> lines,
  ) async {
    final secretPatterns = [
      'api_key',
      'secret_key',
      'access_token',
      'password',
      'private_key',
    ];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].toLowerCase();

      for (final pattern in secretPatterns) {
        if (line.contains(pattern) &&
            line.contains('=') &&
            !_isLikelyTemplate(line)) {
          _addFinding(
            SecurityFinding(
              type: SecurityFindingType.hardcodedSecret,
              severity: SecuritySeverity.critical,
              file: file.path,
              line: i + 1,
              description:
                  'Potential hardcoded secret or credential detected: $pattern',
              evidence: lines[i].trim(),
              recommendation:
                  'Move secrets to environment variables or secure configuration',
              category: 'Secrets Management',
              cweId: 'CWE-798',
            ),
          );
        }
      }
    }
  }

  /// Check for insecure coding patterns
  Future<void> _checkInsecurePatterns(
    File file,
    String content,
    List<String> lines,
  ) async {
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Check for SQL injection potential
      if (line.contains('query') && line.contains('\${')) {
        _addFinding(
          SecurityFinding(
            type: SecurityFindingType.insecurePattern,
            severity: SecuritySeverity.high,
            file: file.path,
            line: i + 1,
            description:
                'Potential SQL injection vulnerability - string interpolation in query',
            evidence: line.trim(),
            recommendation: 'Use parameterized queries or prepared statements',
            category: 'Injection',
            cweId: 'CWE-89',
          ),
        );
      }

      // Check for insecure HTTP usage
      if (line.contains('http://') && !line.contains('localhost')) {
        _addFinding(
          SecurityFinding(
            type: SecurityFindingType.insecurePattern,
            severity: SecuritySeverity.medium,
            file: file.path,
            line: i + 1,
            description: 'Using insecure HTTP protocol',
            evidence: line.trim(),
            recommendation: 'Use HTTPS for all network communications',
            category: 'Network Security',
            cweId: 'CWE-319',
          ),
        );
      }

      // Check for debug logging of sensitive data
      if (line.contains('print') &&
          (line.contains('password') || line.contains('token'))) {
        _addFinding(
          SecurityFinding(
            type: SecurityFindingType.insecurePattern,
            severity: SecuritySeverity.medium,
            file: file.path,
            line: i + 1,
            description: 'Potential sensitive data logging',
            evidence: line.trim(),
            recommendation: 'Remove debug logging of sensitive information',
            category: 'Information Disclosure',
            cweId: 'CWE-532',
          ),
        );
      }
    }
  }

  /// Check configuration security
  Future<void> _checkConfigurationSecurity(
    File file,
    String content,
    List<String> lines,
  ) async {
    final fileName = file.path.split(Platform.pathSeparator).last;

    // Android security checks
    if (fileName == 'AndroidManifest.xml') {
      await _checkAndroidSecurity(file, content, lines);
    }

    // Pubspec security
    if (fileName == 'pubspec.yaml') {
      await _checkPubspecSecurity(file, content, lines);
    }
  }

  /// Check Android-specific security configurations
  Future<void> _checkAndroidSecurity(
    File file,
    String content,
    List<String> lines,
  ) async {
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Check for debug mode
      if (line.contains('android:debuggable="true"')) {
        _addFinding(
          SecurityFinding(
            type: SecurityFindingType.configuration,
            severity: SecuritySeverity.high,
            file: file.path,
            line: i + 1,
            description: 'Debug mode enabled in production manifest',
            evidence: line.trim(),
            recommendation: 'Disable debug mode for production builds',
            category: 'Debug Configuration',
            cweId: 'CWE-489',
          ),
        );
      }

      // Check for clear text traffic
      if (line.contains('android:usesCleartextTraffic="true"')) {
        _addFinding(
          SecurityFinding(
            type: SecurityFindingType.configuration,
            severity: SecuritySeverity.high,
            file: file.path,
            line: i + 1,
            description: 'Clear text traffic allowed',
            evidence: line.trim(),
            recommendation: 'Disable clear text traffic for production',
            category: 'Network Security',
            cweId: 'CWE-319',
          ),
        );
      }
    }
  }

  /// Check pubspec.yaml for security issues
  Future<void> _checkPubspecSecurity(
    File file,
    String content,
    List<String> lines,
  ) async {
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.contains('git:') && line.contains('github.com')) {
        _addFinding(
          SecurityFinding(
            type: SecurityFindingType.configuration,
            severity: SecuritySeverity.medium,
            file: file.path,
            line: i + 1,
            description:
                'Git dependency detected - potential supply chain risk',
            evidence: line.trim(),
            recommendation:
                'Use pub.dev packages when possible, review git dependencies carefully',
            category: 'Supply Chain',
            cweId: 'CWE-829',
          ),
        );
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
    _riskCategories[finding.category] =
        (_riskCategories[finding.category] ?? 0) + 1;
  }

  /// Generate comprehensive security report
  CodeSecurityReport _generateReport() {
    final criticalFindings = _findings
        .where((f) => f.severity == SecuritySeverity.critical)
        .toList();
    final highFindings = _findings
        .where((f) => f.severity == SecuritySeverity.high)
        .toList();
    final mediumFindings = _findings
        .where((f) => f.severity == SecuritySeverity.medium)
        .toList();
    final lowFindings = _findings
        .where((f) => f.severity == SecuritySeverity.low)
        .toList();

    SecurityLogger.info('📋 Static Code Analysis Summary:');
    SecurityLogger.info('   🔴 Critical: ${criticalFindings.length}');
    SecurityLogger.info('   🟠 High: ${highFindings.length}');
    SecurityLogger.info('   🟡 Medium: ${mediumFindings.length}');
    SecurityLogger.info('   🟢 Low: ${lowFindings.length}');
    SecurityLogger.info('   📊 Total Findings: ${_findings.length}');

    // Log top risk categories
    if (_riskCategories.isNotEmpty) {
      SecurityLogger.info('📊 Top Risk Categories:');
      final sortedCategories = _riskCategories.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      for (int i = 0; i < 5 && i < sortedCategories.length; i++) {
        final entry = sortedCategories[i];
        SecurityLogger.info('   ${i + 1}. ${entry.key}: ${entry.value} issues');
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
      recommendations.add(
        '🔑 Move all hardcoded secrets to environment variables',
      );
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

    SecurityLogger.info('💾 Report saved to: ${reportFile.path}');
    SecurityLogger.info(
      '📄 View detailed report at: ${reportFile.absolute.path}',
    );
  }
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
enum SecuritySeverity { critical, high, medium, low }

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
    // Validate environment
    final currentDir = Directory.current;
    if (!currentDir.existsSync()) {
      throw Exception('Current directory does not exist');
    }

    // Check if this is a Flutter/Dart project
    final pubspecFile = File('pubspec.yaml');
    if (!pubspecFile.existsSync()) {
      throw Exception(
        'pubspec.yaml not found. This does not appear to be a Dart/Flutter project.',
      );
    }

    final analyzer = CodeSecurityAnalyzer();
    final report = await analyzer.analyzeCodebase();

    // Validate report
    if (report.totalFindings < 0) {
      throw Exception('Invalid report generated');
    }

    if (report.totalFiles == 0) {
      SecurityLogger.warning(
        'No files were analyzed. Check if the project structure is correct.',
      );
    }

    SecurityLogger.info('✅ Code security analysis completed successfully!');

    if (report.criticalFindings > 0 || report.highFindings > 0) {
      SecurityLogger.warning(
        '⚠️ Security issues found that require attention!',
      );
      exit(1);
    }

    exit(0);
  } catch (e, stackTrace) {
    SecurityLogger.error('❌ Code security analysis failed: $e', error: e);
    SecurityLogger.error('Stack trace: $stackTrace');
    exit(1);
  }
}
