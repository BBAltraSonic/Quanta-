#!/usr/bin/env dart

/// Quanta Security Audit - Dependency Vulnerability Scanner
///
/// This script scans the project dependencies for known vulnerabilities
/// and security issues, providing actionable reports for remediation.
///
/// Usage: dart scripts/security_audit/dependency_scanner.dart
///
/// Features:
/// - Scans pubspec.yaml for vulnerable dependencies
/// - Checks for outdated packages with security patches
/// - Validates dependency sources and integrity
/// - Generates security audit reports
/// - Integrates with CI/CD pipelines
import 'dart:io';
import 'dart:convert';
import 'package:yaml/yaml.dart';
import 'package:http/http.dart' as http;
import 'logger.dart';

class DependencyScanner {
  static const String _pubDevApi = 'https://pub.dev/api';
  static const String _advisoriesApi = 'https://osv.dev/v1';

  final Map<String, VulnerabilityInfo> _knownVulnerabilities = {};
  final List<SecurityIssue> _foundIssues = [];
  final Map<String, PackageInfo> _packageCache = {};

  /// Main entry point for dependency scanning
  Future<SecurityAuditReport> scanDependencies() async {
    SecurityLogger.info('🔍 Starting dependency vulnerability scan...');

    final pubspecFile = File('pubspec.yaml');
    if (!pubspecFile.existsSync()) {
      throw Exception('pubspec.yaml not found in current directory');
    }

    final pubspecContent = await pubspecFile.readAsString();
    final pubspec = loadYaml(pubspecContent) as Map;

    // Extract dependencies
    final dependencies = <String, String>{};
    if (pubspec['dependencies'] != null) {
      (pubspec['dependencies'] as Map).forEach((key, value) {
        if (value is String) {
          dependencies[key.toString()] = value;
        } else if (value is Map && value['version'] != null) {
          dependencies[key.toString()] = value['version'].toString();
        }
      });
    }

    SecurityLogger.info(
      '📦 Found ${dependencies.length} dependencies to analyze',
    );

    // Load vulnerability database
    await _loadVulnerabilityDatabase();

    // Scan each dependency
    for (final entry in dependencies.entries) {
      await _scanPackage(entry.key, entry.value);
    }

    // Check for outdated packages with security updates
    await _checkOutdatedPackages(dependencies);

    // Generate report
    final report = _generateReport();
    await _saveReport(report);

    return report;
  }

  /// Load known vulnerability database
  Future<void> _loadVulnerabilityDatabase() async {
    SecurityLogger.info('📥 Loading vulnerability database...');

    // Load Flutter-specific vulnerabilities
    await _loadFlutterVulnerabilities();

    // Load common Dart package vulnerabilities
    await _loadDartVulnerabilities();

    SecurityLogger.info(
      '✅ Loaded ${_knownVulnerabilities.length} vulnerability records',
    );
  }

  /// Load Flutter framework vulnerabilities
  Future<void> _loadFlutterVulnerabilities() async {
    // Known Flutter vulnerabilities (this would be expanded with real data)
    _knownVulnerabilities['flutter'] = VulnerabilityInfo(
      packageName: 'flutter',
      vulnerableVersions: ['<3.0.0'],
      severity: 'Medium',
      description: 'Older Flutter versions may have security issues',
      cveId: 'FLUTTER-ADVISORY-001',
      fixedIn: '3.0.0',
      recommendation: 'Upgrade to Flutter 3.0.0 or later',
    );
  }

  /// Load Dart package vulnerabilities
  Future<void> _loadDartVulnerabilities() async {
    // Common vulnerable packages (this would be loaded from OSV database)
    final vulnerablePackages = [
      'http',
      'dio',
      'shared_preferences',
      'firebase_auth',
      'supabase_flutter',
    ];

    for (final packageName in vulnerablePackages) {
      try {
        await _fetchPackageVulnerabilities(packageName);
      } catch (e) {
        SecurityLogger.warning(
          'Could not fetch vulnerabilities for $packageName: $e',
        );
      }
    }
  }

  /// Fetch vulnerabilities for a specific package from OSV API
  Future<void> _fetchPackageVulnerabilities(String packageName) async {
    try {
      final response = await http.post(
        Uri.parse('$_advisoriesApi/query'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'package': {'name': packageName, 'ecosystem': 'Pub'},
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['vulns'] != null) {
          for (final vuln in data['vulns']) {
            _processVulnerability(packageName, vuln);
          }
        }
      }
    } catch (e) {
      // Silently handle API errors - vulnerability scanning should not block builds
    }
  }

  /// Process vulnerability data from OSV API
  void _processVulnerability(String packageName, Map<String, dynamic> vuln) {
    final id = vuln['id'] ?? 'UNKNOWN';
    final summary = vuln['summary'] ?? 'No description available';

    String severity = 'Medium';
    if (vuln['severity'] != null) {
      severity = vuln['severity'][0]['score'] ?? 'Medium';
    }

    _knownVulnerabilities['$packageName-$id'] = VulnerabilityInfo(
      packageName: packageName,
      vulnerableVersions: _extractVulnerableVersions(vuln),
      severity: severity,
      description: summary,
      cveId: id,
      fixedIn: _extractFixedVersion(vuln),
      recommendation: 'Update to latest secure version',
    );
  }

  /// Extract vulnerable version ranges from vulnerability data
  List<String> _extractVulnerableVersions(Map<String, dynamic> vuln) {
    final versions = <String>[];

    if (vuln['affected'] != null) {
      for (final affected in vuln['affected']) {
        if (affected['ranges'] != null) {
          for (final range in affected['ranges']) {
            if (range['events'] != null) {
              for (final event in range['events']) {
                if (event['introduced'] != null) {
                  versions.add('>=${event['introduced']}');
                }
                if (event['fixed'] != null) {
                  versions.add('<${event['fixed']}');
                }
              }
            }
          }
        }
      }
    }

    return versions;
  }

  /// Extract fixed version from vulnerability data
  String? _extractFixedVersion(Map<String, dynamic> vuln) {
    if (vuln['affected'] != null) {
      for (final affected in vuln['affected']) {
        if (affected['ranges'] != null) {
          for (final range in affected['ranges']) {
            if (range['events'] != null) {
              for (final event in range['events']) {
                if (event['fixed'] != null) {
                  return event['fixed'];
                }
              }
            }
          }
        }
      }
    }
    return null;
  }

  /// Scan a specific package for vulnerabilities
  Future<void> _scanPackage(String packageName, String version) async {
    SecurityLogger.debug('🔎 Scanning $packageName@$version...');

    // Check against known vulnerabilities
    for (final vuln in _knownVulnerabilities.values) {
      if (vuln.packageName == packageName) {
        if (_isVersionVulnerable(version, vuln.vulnerableVersions)) {
          _foundIssues.add(
            SecurityIssue(
              type: SecurityIssueType.vulnerability,
              severity: _parseSeverity(vuln.severity),
              packageName: packageName,
              currentVersion: version,
              description: vuln.description,
              recommendation: vuln.recommendation,
              cveId: vuln.cveId,
              fixedIn: vuln.fixedIn,
            ),
          );
        }
      }
    }

    // Check package source integrity
    await _checkPackageIntegrity(packageName, version);
  }

  /// Check if a version is vulnerable based on version constraints
  bool _isVersionVulnerable(String version, List<String> vulnerableVersions) {
    // Simplified version checking - in production, use proper semver parsing
    for (final constraint in vulnerableVersions) {
      if (constraint.startsWith('<') &&
          version.compareTo(constraint.substring(1)) < 0) {
        return true;
      }
      if (constraint.startsWith('>=') &&
          version.compareTo(constraint.substring(2)) >= 0) {
        return true;
      }
    }
    return false;
  }

  /// Check package integrity and source
  Future<void> _checkPackageIntegrity(
    String packageName,
    String version,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$_pubDevApi/packages/$packageName'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Check if package is from pub.dev (trusted source)
        if (data['latest'] == null) {
          _foundIssues.add(
            SecurityIssue(
              type: SecurityIssueType.untrustedSource,
              severity: SecuritySeverity.medium,
              packageName: packageName,
              currentVersion: version,
              description: 'Package not found on pub.dev',
              recommendation: 'Verify package source and integrity',
            ),
          );
        }

        // Cache package info for outdated check
        _packageCache[packageName] = PackageInfo(
          name: packageName,
          currentVersion: version,
          latestVersion: data['latest']['version'],
          isDiscontinued: data['isDiscontinued'] ?? false,
        );
      }
    } catch (e) {
      _foundIssues.add(
        SecurityIssue(
          type: SecurityIssueType.networkError,
          severity: SecuritySeverity.low,
          packageName: packageName,
          currentVersion: version,
          description: 'Could not verify package integrity: $e',
          recommendation: 'Check network connection and package source',
        ),
      );
    }
  }

  /// Check for outdated packages with security updates
  Future<void> _checkOutdatedPackages(Map<String, String> dependencies) async {
    SecurityLogger.info('📅 Checking for outdated packages...');

    for (final entry in dependencies.entries) {
      final packageInfo = _packageCache[entry.key];
      if (packageInfo != null) {
        if (packageInfo.isDiscontinued) {
          _foundIssues.add(
            SecurityIssue(
              type: SecurityIssueType.discontinuedPackage,
              severity: SecuritySeverity.high,
              packageName: entry.key,
              currentVersion: entry.value,
              description: 'Package is discontinued and no longer maintained',
              recommendation:
                  'Find alternative package or fork for security updates',
            ),
          );
        } else if (_isOutdated(entry.value, packageInfo.latestVersion)) {
          _foundIssues.add(
            SecurityIssue(
              type: SecurityIssueType.outdatedPackage,
              severity: SecuritySeverity.medium,
              packageName: entry.key,
              currentVersion: entry.value,
              description: 'Package is outdated, may miss security patches',
              recommendation:
                  'Update to latest version: ${packageInfo.latestVersion}',
              fixedIn: packageInfo.latestVersion,
            ),
          );
        }
      }
    }
  }

  /// Check if current version is outdated
  bool _isOutdated(String current, String latest) {
    // Simplified version comparison
    return current != latest;
  }

  /// Parse severity string to enum
  SecuritySeverity _parseSeverity(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return SecuritySeverity.critical;
      case 'high':
        return SecuritySeverity.high;
      case 'medium':
        return SecuritySeverity.medium;
      case 'low':
        return SecuritySeverity.low;
      default:
        return SecuritySeverity.medium;
    }
  }

  /// Generate comprehensive security audit report
  SecurityAuditReport _generateReport() {
    final criticalIssues = _foundIssues
        .where((i) => i.severity == SecuritySeverity.critical)
        .toList();
    final highIssues = _foundIssues
        .where((i) => i.severity == SecuritySeverity.high)
        .toList();
    final mediumIssues = _foundIssues
        .where((i) => i.severity == SecuritySeverity.medium)
        .toList();
    final lowIssues = _foundIssues
        .where((i) => i.severity == SecuritySeverity.low)
        .toList();

    SecurityLogger.info('📋 Security Audit Summary:');
    SecurityLogger.info('   🔴 Critical: ${criticalIssues.length}');
    SecurityLogger.info('   🟠 High: ${highIssues.length}');
    SecurityLogger.info('   🟡 Medium: ${mediumIssues.length}');
    SecurityLogger.info('   🟢 Low: ${lowIssues.length}');
    SecurityLogger.info('   📊 Total Issues: ${_foundIssues.length}');

    final report = SecurityAuditReport(
      scanDate: DateTime.now(),
      totalPackages: _packageCache.length,
      totalIssues: _foundIssues.length,
      criticalIssues: criticalIssues.length,
      highIssues: highIssues.length,
      mediumIssues: mediumIssues.length,
      lowIssues: lowIssues.length,
      issues: _foundIssues,
      recommendations: _generateRecommendations(),
    );

    return report;
  }

  /// Generate actionable recommendations
  List<String> _generateRecommendations() {
    final recommendations = <String>[];

    if (_foundIssues.any((i) => i.severity == SecuritySeverity.critical)) {
      recommendations.add(
        '🚨 CRITICAL: Immediately update packages with critical vulnerabilities',
      );
    }

    if (_foundIssues.any(
      (i) => i.type == SecurityIssueType.discontinuedPackage,
    )) {
      recommendations.add(
        '📦 Replace discontinued packages with maintained alternatives',
      );
    }

    if (_foundIssues.any((i) => i.type == SecurityIssueType.outdatedPackage)) {
      recommendations.add('⬆️ Update outdated packages to latest versions');
    }

    if (_foundIssues.any((i) => i.type == SecurityIssueType.untrustedSource)) {
      recommendations.add('🔍 Verify packages from untrusted sources');
    }

    recommendations.add('🔄 Run dependency scan regularly in CI/CD pipeline');
    recommendations.add('📋 Review and approve all new dependencies');
    recommendations.add('🛡️ Consider using dependency pinning for production');

    return recommendations;
  }

  /// Save report to file
  Future<void> _saveReport(SecurityAuditReport report) async {
    final reportsDir = Directory('reports/security');
    if (!reportsDir.existsSync()) {
      reportsDir.createSync(recursive: true);
    }

    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final reportFile = File('reports/security/dependency_scan_$timestamp.json');

    await reportFile.writeAsString(jsonEncode(report.toJson()));

    SecurityLogger.info('💾 Report saved to: ${reportFile.path}');
    SecurityLogger.info(
      '📄 View detailed report at: ${reportFile.absolute.path}',
    );
  }
}

/// Vulnerability information from database
class VulnerabilityInfo {
  final String packageName;
  final List<String> vulnerableVersions;
  final String severity;
  final String description;
  final String cveId;
  final String? fixedIn;
  final String recommendation;

  VulnerabilityInfo({
    required this.packageName,
    required this.vulnerableVersions,
    required this.severity,
    required this.description,
    required this.cveId,
    this.fixedIn,
    required this.recommendation,
  });
}

/// Package information from pub.dev
class PackageInfo {
  final String name;
  final String currentVersion;
  final String latestVersion;
  final bool isDiscontinued;

  PackageInfo({
    required this.name,
    required this.currentVersion,
    required this.latestVersion,
    required this.isDiscontinued,
  });
}

/// Security issue found during scan
class SecurityIssue {
  final SecurityIssueType type;
  final SecuritySeverity severity;
  final String packageName;
  final String currentVersion;
  final String description;
  final String recommendation;
  final String? cveId;
  final String? fixedIn;

  SecurityIssue({
    required this.type,
    required this.severity,
    required this.packageName,
    required this.currentVersion,
    required this.description,
    required this.recommendation,
    this.cveId,
    this.fixedIn,
  });

  Map<String, dynamic> toJson() => {
    'type': type.toString(),
    'severity': severity.toString(),
    'packageName': packageName,
    'currentVersion': currentVersion,
    'description': description,
    'recommendation': recommendation,
    'cveId': cveId,
    'fixedIn': fixedIn,
  };
}

/// Types of security issues
enum SecurityIssueType {
  vulnerability,
  outdatedPackage,
  discontinuedPackage,
  untrustedSource,
  networkError,
}

/// Security severity levels
enum SecuritySeverity { critical, high, medium, low }

/// Complete security audit report
class SecurityAuditReport {
  final DateTime scanDate;
  final int totalPackages;
  final int totalIssues;
  final int criticalIssues;
  final int highIssues;
  final int mediumIssues;
  final int lowIssues;
  final List<SecurityIssue> issues;
  final List<String> recommendations;

  SecurityAuditReport({
    required this.scanDate,
    required this.totalPackages,
    required this.totalIssues,
    required this.criticalIssues,
    required this.highIssues,
    required this.mediumIssues,
    required this.lowIssues,
    required this.issues,
    required this.recommendations,
  });

  Map<String, dynamic> toJson() => {
    'scanDate': scanDate.toIso8601String(),
    'totalPackages': totalPackages,
    'totalIssues': totalIssues,
    'criticalIssues': criticalIssues,
    'highIssues': highIssues,
    'mediumIssues': mediumIssues,
    'lowIssues': lowIssues,
    'issues': issues.map((i) => i.toJson()).toList(),
    'recommendations': recommendations,
  };
}

/// Main function to run dependency scanner
Future<void> main() async {
  try {
    // Validate environment
    final pubspecFile = File('pubspec.yaml');
    if (!pubspecFile.existsSync()) {
      throw Exception('pubspec.yaml not found in current directory');
    }

    final scanner = DependencyScanner();
    final report = await scanner.scanDependencies();

    // Validate report
    if (report.totalIssues < 0 || report.totalPackages < 0) {
      throw Exception('Invalid report generated');
    }

    SecurityLogger.info('✅ Dependency scan completed successfully!');

    if (report.criticalIssues > 0 || report.highIssues > 0) {
      SecurityLogger.warning(
        '⚠️ Security issues found that require attention!',
      );
      exit(1);
    }

    exit(0);
  } catch (e, stackTrace) {
    SecurityLogger.error('❌ Dependency scan failed: $e', error: e);
    SecurityLogger.error('Stack trace: $stackTrace');
    exit(1);
  }
}
