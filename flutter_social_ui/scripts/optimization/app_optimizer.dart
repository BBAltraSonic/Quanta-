#!/usr/bin/env dart

/// Quanta App Optimization Tool
/// 
/// This script analyzes and optimizes the app for size and performance,
/// providing recommendations and automated optimizations where possible.
/// 
/// Usage: dart scripts/optimization/app_optimizer.dart

import 'dart:io';
import 'dart:convert';

class AppOptimizer {
  final List<OptimizationResult> _results = [];
  final Map<String, dynamic> _metrics = {};

  /// Run comprehensive app optimization analysis
  Future<OptimizationReport> runOptimization() async {
    print('🚀 Starting app optimization analysis...\n');
    
    await _analyzeAppSize();
    await _analyzeDependencies();
    await _analyzeAssets();
    await _analyzeCode();
    await _analyzePerformance();
    await _generateOptimizations();
    
    final report = _generateReport();
    await _saveReport(report);
    
    return report;
  }

  /// Analyze current app size
  Future<void> _analyzeAppSize() async {
    print('📦 Analyzing app size...');
    
    // Analyze APK size if exists
    final apkPath = 'build/app/outputs/flutter-apk/app-release.apk';
    if (File(apkPath).existsSync()) {
      final apkSize = await File(apkPath).length();
      _metrics['apk_size_mb'] = (apkSize / (1024 * 1024)).toStringAsFixed(2);
      
      if (apkSize > 50 * 1024 * 1024) { // > 50MB
        _addResult(OptimizationResult(
          category: 'App Size',
          issue: 'Large APK size',
          impact: OptimizationImpact.high,
          description: 'APK size is ${_metrics['apk_size_mb']}MB',
          recommendation: 'Implement app bundle and asset optimization',
          autoFixAvailable: true,
        ));
      }
    }
    
    // Analyze build size breakdown
    await _analyzeBuildSize();
    
    print('✅ App size analysis completed');
  }

  /// Analyze build size breakdown
  Future<void> _analyzeBuildSize() async {
    final buildDir = Directory('build');
    if (!buildDir.existsSync()) {
      _addResult(OptimizationResult(
        category: 'Build Analysis',
        issue: 'No build directory found',
        impact: OptimizationImpact.low,
        description: 'Run flutter build to analyze app size',
        recommendation: 'Build the app first to enable size analysis',
      ));
      return;
    }

    // Analyze assets
    final assetsDir = Directory('assets');
    if (assetsDir.existsSync()) {
      int totalAssetSize = 0;
      await for (final file in assetsDir.list(recursive: true)) {
        if (file is File) {
          totalAssetSize += await file.length();
        }
      }
      
      _metrics['assets_size_mb'] = (totalAssetSize / (1024 * 1024)).toStringAsFixed(2);
      
      if (totalAssetSize > 20 * 1024 * 1024) { // > 20MB
        _addResult(OptimizationResult(
          category: 'Assets',
          issue: 'Large assets size',
          impact: OptimizationImpact.medium,
          description: 'Assets total ${_metrics['assets_size_mb']}MB',
          recommendation: 'Optimize images and remove unused assets',
          autoFixAvailable: true,
        ));
      }
    }
  }

  /// Analyze dependencies for optimization opportunities
  Future<void> _analyzeDependencies() async {
    print('📚 Analyzing dependencies...');
    
    final pubspecFile = File('pubspec.yaml');
    if (!pubspecFile.existsSync()) {
      return;
    }
    
    final content = await pubspecFile.readAsString();
    final lines = content.split('\n');
    
    int dependencyCount = 0;
    final largeDependencies = <String>[];
    
    bool inDependencies = false;
    for (final line in lines) {
      if (line.trim().startsWith('dependencies:')) {
        inDependencies = true;
        continue;
      }
      
      if (line.trim().startsWith('dev_dependencies:')) {
        inDependencies = false;
        continue;
      }
      
      if (inDependencies && line.trim().isNotEmpty && !line.startsWith(' ')) {
        inDependencies = false;
      }
      
      if (inDependencies && line.contains(':')) {
        dependencyCount++;
        
        // Check for potentially large dependencies
        final dependency = line.split(':')[0].trim();
        if (_isLargeDependency(dependency)) {
          largeDependencies.add(dependency);
        }
      }
    }
    
    _metrics['dependency_count'] = dependencyCount;
    
    if (dependencyCount > 30) {
      _addResult(OptimizationResult(
        category: 'Dependencies',
        issue: 'High dependency count',
        impact: OptimizationImpact.medium,
        description: '$dependencyCount dependencies detected',
        recommendation: 'Review and remove unused dependencies',
        autoFixAvailable: false,
      ));
    }
    
    if (largeDependencies.isNotEmpty) {
      _addResult(OptimizationResult(
        category: 'Dependencies',
        issue: 'Large dependencies detected',
        impact: OptimizationImpact.medium,
        description: 'Large deps: ${largeDependencies.join(', ')}',
        recommendation: 'Consider lighter alternatives or lazy loading',
        autoFixAvailable: false,
      ));
    }
    
    print('✅ Dependencies analysis completed');
  }

  /// Check if dependency is known to be large
  bool _isLargeDependency(String dependency) {
    final largeDeps = [
      'camera',
      'image_picker',
      'video_player',
      'webview_flutter',
      'firebase_core',
      'google_maps_flutter',
    ];
    
    return largeDeps.any((large) => dependency.contains(large));
  }

  /// Analyze assets for optimization
  Future<void> _analyzeAssets() async {
    print('🖼️ Analyzing assets...');
    
    final assetsDir = Directory('assets');
    if (!assetsDir.existsSync()) {
      print('ℹ️ No assets directory found');
      return;
    }
    
    final imageExtensions = ['.png', '.jpg', '.jpeg', '.gif', '.webp'];
    final largeImages = <String>[];
    final unoptimizedImages = <String>[];
    
    await for (final file in assetsDir.list(recursive: true)) {
      if (file is File) {
        final extension = file.path.split('.').last.toLowerCase();
        
        if (imageExtensions.contains('.$extension')) {
          final size = await file.length();
          
          // Check for large images (> 1MB)
          if (size > 1024 * 1024) {
            largeImages.add(file.path);
          }
          
          // Check for unoptimized formats
          if (extension == 'png' || extension == 'jpg') {
            unoptimizedImages.add(file.path);
          }
        }
      }
    }
    
    if (largeImages.isNotEmpty) {
      _addResult(OptimizationResult(
        category: 'Assets',
        issue: 'Large image files',
        impact: OptimizationImpact.high,
        description: '${largeImages.length} images > 1MB',
        recommendation: 'Compress large images or use progressive loading',
        autoFixAvailable: true,
      ));
    }
    
    if (unoptimizedImages.length > 5) {
      _addResult(OptimizationResult(
        category: 'Assets',
        issue: 'Unoptimized image formats',
        impact: OptimizationImpact.medium,
        description: '${unoptimizedImages.length} PNG/JPG images',
        recommendation: 'Convert to WebP format for better compression',
        autoFixAvailable: true,
      ));
    }
    
    print('✅ Assets analysis completed');
  }

  /// Analyze code for optimization opportunities
  Future<void> _analyzeCode() async {
    print('💻 Analyzing code...');
    
    await _analyzeFlutterCode();
    await _analyzeUnusedCode();
    
    print('✅ Code analysis completed');
  }

  /// Analyze Flutter-specific code patterns
  Future<void> _analyzeFlutterCode() async {
    final libDir = Directory('lib');
    if (!libDir.existsSync()) {
      return;
    }
    
    int widgetCount = 0;
    int buildMethodCount = 0;
    final complexWidgets = <String>[];
    
    await for (final file in libDir.list(recursive: true)) {
      if (file is File && file.path.endsWith('.dart')) {
        final content = await file.readAsString();
        
        // Count widgets and build methods
        widgetCount += 'StatelessWidget'.allMatches(content).length;
        widgetCount += 'StatefulWidget'.allMatches(content).length;
        buildMethodCount += 'Widget build('.allMatches(content).length;
        
        // Check for complex widgets (large build methods)
        if (_hasComplexBuildMethod(content)) {
          complexWidgets.add(file.path);
        }
      }
    }
    
    _metrics['widget_count'] = widgetCount;
    _metrics['build_method_count'] = buildMethodCount;
    
    if (complexWidgets.isNotEmpty) {
      _addResult(OptimizationResult(
        category: 'Code Structure',
        issue: 'Complex build methods detected',
        impact: OptimizationImpact.medium,
        description: '${complexWidgets.length} files with complex builds',
        recommendation: 'Break down large build methods into smaller widgets',
        autoFixAvailable: false,
      ));
    }
  }

  /// Check if file has complex build method
  bool _hasComplexBuildMethod(String content) {
    final lines = content.split('\n');
    bool inBuildMethod = false;
    int buildMethodLines = 0;
    
    for (final line in lines) {
      if (line.contains('Widget build(')) {
        inBuildMethod = true;
        buildMethodLines = 0;
      }
      
      if (inBuildMethod) {
        buildMethodLines++;
        
        if (line.trim() == '}' && buildMethodLines > 1) {
          if (buildMethodLines > 50) { // Large build method
            return true;
          }
          inBuildMethod = false;
        }
      }
    }
    
    return false;
  }

  /// Analyze for unused code
  Future<void> _analyzeUnusedCode() async {
    // This is a simplified analysis - in production, use tools like dart_code_metrics
    final libDir = Directory('lib');
    if (!libDir.existsSync()) {
      return;
    }
    
    final allFiles = <String>[];
    final importedFiles = <String>{};
    
    await for (final file in libDir.list(recursive: true)) {
      if (file is File && file.path.endsWith('.dart')) {
        allFiles.add(file.path);
        
        final content = await file.readAsString();
        final imports = RegExp(r"import\s+['\"](.+?)['\"]").allMatches(content);
        
        for (final match in imports) {
          final importPath = match.group(1);
          if (importPath != null && importPath.startsWith('package:')) {
            // Skip package imports
            continue;
          }
          if (importPath != null) {
            importedFiles.add(importPath);
          }
        }
      }
    }
    
    // Simplified unused file detection
    final potentiallyUnused = allFiles.where((file) => 
      !importedFiles.any((imported) => file.contains(imported))
    ).length;
    
    if (potentiallyUnused > 5) {
      _addResult(OptimizationResult(
        category: 'Code Cleanup',
        issue: 'Potentially unused files',
        impact: OptimizationImpact.low,
        description: '$potentiallyUnused files may be unused',
        recommendation: 'Review and remove unused files',
        autoFixAvailable: false,
      ));
    }
  }

  /// Analyze performance characteristics
  Future<void> _analyzePerformance() async {
    print('⚡ Analyzing performance characteristics...');
    
    // Check for common performance issues
    await _checkPerformancePatterns();
    
    print('✅ Performance analysis completed');
  }

  /// Check for performance anti-patterns
  Future<void> _checkPerformancePatterns() async {
    final libDir = Directory('lib');
    if (!libDir.existsSync()) {
      return;
    }
    
    final performanceIssues = <String>[];
    
    await for (final file in libDir.list(recursive: true)) {
      if (file is File && file.path.endsWith('.dart')) {
        final content = await file.readAsString();
        
        // Check for expensive operations in build methods
        if (content.contains('build(') && 
            (content.contains('Future') || content.contains('async'))) {
          performanceIssues.add('Async operations in build method: ${file.path}');
        }
        
        // Check for frequent rebuilds
        if (content.contains('setState') && 
            content.split('setState').length > 5) {
          performanceIssues.add('Frequent setState calls: ${file.path}');
        }
      }
    }
    
    if (performanceIssues.isNotEmpty) {
      _addResult(OptimizationResult(
        category: 'Performance',
        issue: 'Performance anti-patterns detected',
        impact: OptimizationImpact.high,
        description: '${performanceIssues.length} potential issues',
        recommendation: 'Review async operations and state management',
        autoFixAvailable: false,
      ));
    }
  }

  /// Generate optimization recommendations
  Future<void> _generateOptimizations() async {
    print('🔧 Generating optimization recommendations...');
    
    // Add general Flutter optimizations
    _addResult(OptimizationResult(
      category: 'Build Optimization',
      issue: 'Build configuration',
      impact: OptimizationImpact.medium,
      description: 'Enable build optimizations',
      recommendation: 'Use --split-debug-info and --obfuscate for release builds',
      autoFixAvailable: true,
    ));
    
    _addResult(OptimizationResult(
      category: 'Bundle Optimization',
      issue: 'App bundle configuration',
      impact: OptimizationImpact.high,
      description: 'Optimize app bundle delivery',
      recommendation: 'Use Android App Bundle with dynamic delivery',
      autoFixAvailable: true,
    ));
    
    print('✅ Optimization recommendations generated');
  }

  /// Add optimization result
  void _addResult(OptimizationResult result) {
    _results.add(result);
  }

  /// Generate optimization report
  OptimizationReport _generateReport() {
    final highImpact = _results.where((r) => r.impact == OptimizationImpact.high).length;
    final mediumImpact = _results.where((r) => r.impact == OptimizationImpact.medium).length;
    final lowImpact = _results.where((r) => r.impact == OptimizationImpact.low).length;
    final autoFixable = _results.where((r) => r.autoFixAvailable).length;

    print('\n📋 Optimization Analysis Summary:');
    print('   🔴 High Impact: $highImpact');
    print('   🟡 Medium Impact: $mediumImpact');
    print('   🟢 Low Impact: $lowImpact');
    print('   🔧 Auto-fixable: $autoFixable');
    print('   📊 Total Issues: ${_results.length}');

    return OptimizationReport(
      analysisDate: DateTime.now(),
      totalIssues: _results.length,
      highImpactIssues: highImpact,
      mediumImpactIssues: mediumImpact,
      lowImpactIssues: lowImpact,
      autoFixableIssues: autoFixable,
      results: _results,
      metrics: _metrics,
      recommendations: _generateFinalRecommendations(),
    );
  }

  /// Generate final recommendations
  List<String> _generateFinalRecommendations() {
    final recommendations = <String>[];
    
    if (_results.any((r) => r.impact == OptimizationImpact.high)) {
      recommendations.add('🚨 Address high-impact optimizations first');
    }
    
    if (_results.any((r) => r.category == 'App Size')) {
      recommendations.add('📦 Implement app size reduction strategies');
    }
    
    if (_results.any((r) => r.category == 'Performance')) {
      recommendations.add('⚡ Optimize performance-critical code paths');
    }
    
    recommendations.add('🔧 Run optimization tools regularly');
    recommendations.add('📊 Monitor app performance metrics');
    recommendations.add('🔄 Integrate optimization checks into CI/CD');
    
    return recommendations;
  }

  /// Save optimization report
  Future<void> _saveReport(OptimizationReport report) async {
    final reportsDir = Directory('reports/optimization');
    if (!reportsDir.existsSync()) {
      reportsDir.createSync(recursive: true);
    }
    
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final reportFile = File('reports/optimization/app_optimization_$timestamp.json');
    
    await reportFile.writeAsString(jsonEncode(report.toJson()));
    
    print('\n💾 Report saved to: ${reportFile.path}');
  }
}

/// Optimization result
class OptimizationResult {
  final String category;
  final String issue;
  final OptimizationImpact impact;
  final String description;
  final String recommendation;
  final bool autoFixAvailable;

  OptimizationResult({
    required this.category,
    required this.issue,
    required this.impact,
    required this.description,
    required this.recommendation,
    this.autoFixAvailable = false,
  });

  Map<String, dynamic> toJson() => {
    'category': category,
    'issue': issue,
    'impact': impact.toString(),
    'description': description,
    'recommendation': recommendation,
    'autoFixAvailable': autoFixAvailable,
  };
}

/// Optimization impact levels
enum OptimizationImpact {
  high,
  medium,
  low,
}

/// Optimization report
class OptimizationReport {
  final DateTime analysisDate;
  final int totalIssues;
  final int highImpactIssues;
  final int mediumImpactIssues;
  final int lowImpactIssues;
  final int autoFixableIssues;
  final List<OptimizationResult> results;
  final Map<String, dynamic> metrics;
  final List<String> recommendations;

  OptimizationReport({
    required this.analysisDate,
    required this.totalIssues,
    required this.highImpactIssues,
    required this.mediumImpactIssues,
    required this.lowImpactIssues,
    required this.autoFixableIssues,
    required this.results,
    required this.metrics,
    required this.recommendations,
  });

  Map<String, dynamic> toJson() => {
    'analysisDate': analysisDate.toIso8601String(),
    'totalIssues': totalIssues,
    'highImpactIssues': highImpactIssues,
    'mediumImpactIssues': mediumImpactIssues,
    'lowImpactIssues': lowImpactIssues,
    'autoFixableIssues': autoFixableIssues,
    'results': results.map((r) => r.toJson()).toList(),
    'metrics': metrics,
    'recommendations': recommendations,
  };
}

/// Main function
Future<void> main() async {
  try {
    final optimizer = AppOptimizer();
    final report = await optimizer.runOptimization();
    
    print('\n✅ App optimization analysis completed!');
    
    if (report.highImpactIssues > 0) {
      print('\n⚠️ High-impact optimizations needed!');
      exit(1);
    }
    
    exit(0);
  } catch (e) {
    print('\n❌ App optimization failed: $e');
    exit(1);
  }
}