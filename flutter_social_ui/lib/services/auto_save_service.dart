import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to handle auto-saving drafts and detecting unsaved changes
class AutoSaveService {
  static const String _draftKeyPrefix = 'draft_';
  static const Duration _autoSaveInterval = Duration(seconds: 30);

  final Map<String, Timer> _autoSaveTimers = {};
  final Map<String, Map<String, dynamic>> _originalValues = {};
  final Map<String, Map<String, dynamic>> _currentValues = {};

  static final AutoSaveService _instance = AutoSaveService._internal();
  factory AutoSaveService() => _instance;
  AutoSaveService._internal();

  /// Initialize auto-save for a specific screen/form
  void initializeAutoSave(String screenId, Map<String, dynamic> initialValues) {
    _originalValues[screenId] = Map.from(initialValues);
    _currentValues[screenId] = Map.from(initialValues);
    _startAutoSave(screenId);
  }

  /// Update current values and trigger auto-save timer reset
  void updateValues(String screenId, Map<String, dynamic> newValues) {
    _currentValues[screenId] = Map.from(newValues);
    _resetAutoSaveTimer(screenId);
  }

  /// Check if there are unsaved changes
  bool hasUnsavedChanges(String screenId) {
    final original = _originalValues[screenId];
    final current = _currentValues[screenId];

    if (original == null || current == null) return false;

    return !_mapsEqual(original, current);
  }

  /// Get the list of changed fields
  List<String> getChangedFields(String screenId) {
    final original = _originalValues[screenId];
    final current = _currentValues[screenId];

    if (original == null || current == null) return [];

    final changedFields = <String>[];
    for (final key in current.keys) {
      if (original[key] != current[key]) {
        changedFields.add(key);
      }
    }

    return changedFields;
  }

  /// Save draft to persistent storage
  Future<void> saveDraft(String screenId) async {
    final current = _currentValues[screenId];
    if (current == null || !hasUnsavedChanges(screenId)) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final draftKey = '$_draftKeyPrefix$screenId';

      final draftData = {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'data': current,
      };

      await prefs.setString(draftKey, jsonEncode(draftData));
    } catch (e) {
      print('Error saving draft: $e');
    }
  }

  /// Load draft from persistent storage
  Future<Map<String, dynamic>?> loadDraft(String screenId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftKey = '$_draftKeyPrefix$screenId';

      final draftString = prefs.getString(draftKey);
      if (draftString == null) return null;

      final draftData = jsonDecode(draftString) as Map<String, dynamic>;
      final timestamp = draftData['timestamp'] as int;
      final data = draftData['data'] as Map<String, dynamic>;

      // Check if draft is not too old (e.g., 7 days)
      final draftAge = DateTime.now().millisecondsSinceEpoch - timestamp;
      const maxAge = 7 * 24 * 60 * 60 * 1000; // 7 days in milliseconds

      if (draftAge > maxAge) {
        await clearDraft(screenId);
        return null;
      }

      return data;
    } catch (e) {
      print('Error loading draft: $e');
      return null;
    }
  }

  /// Clear saved draft
  Future<void> clearDraft(String screenId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftKey = '$_draftKeyPrefix$screenId';
      await prefs.remove(draftKey);
    } catch (e) {
      print('Error clearing draft: $e');
    }
  }

  /// Check if draft exists
  Future<bool> hasDraft(String screenId) async {
    final draft = await loadDraft(screenId);
    return draft != null;
  }

  /// Get draft age in human-readable format
  Future<String?> getDraftAge(String screenId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftKey = '$_draftKeyPrefix$screenId';

      final draftString = prefs.getString(draftKey);
      if (draftString == null) return null;

      final draftData = jsonDecode(draftString) as Map<String, dynamic>;
      final timestamp = draftData['timestamp'] as int;

      final draftTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();
      final difference = now.difference(draftTime);

      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes} minutes ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours} hours ago';
      } else {
        return '${difference.inDays} days ago';
      }
    } catch (e) {
      return null;
    }
  }

  /// Mark changes as saved (update original values)
  void markAsSaved(String screenId) {
    final current = _currentValues[screenId];
    if (current != null) {
      _originalValues[screenId] = Map.from(current);
    }
  }

  /// Dispose auto-save for a screen
  void dispose(String screenId) {
    _autoSaveTimers[screenId]?.cancel();
    _autoSaveTimers.remove(screenId);
    _originalValues.remove(screenId);
    _currentValues.remove(screenId);
  }

  /// Dispose all auto-save timers
  void disposeAll() {
    for (final timer in _autoSaveTimers.values) {
      timer.cancel();
    }
    _autoSaveTimers.clear();
    _originalValues.clear();
    _currentValues.clear();
  }

  void _startAutoSave(String screenId) {
    _autoSaveTimers[screenId] = Timer.periodic(_autoSaveInterval, (
      timer,
    ) async {
      await saveDraft(screenId);
    });
  }

  void _resetAutoSaveTimer(String screenId) {
    _autoSaveTimers[screenId]?.cancel();
    _autoSaveTimers[screenId] = Timer(_autoSaveInterval, () async {
      await saveDraft(screenId);
      _startAutoSave(screenId);
    });
  }

  bool _mapsEqual(Map<String, dynamic> map1, Map<String, dynamic> map2) {
    if (map1.length != map2.length) return false;

    for (final key in map1.keys) {
      if (!map2.containsKey(key)) return false;

      final value1 = map1[key];
      final value2 = map2[key];

      // Handle different types of comparisons
      if (value1 is String && value2 is String) {
        if (value1.trim() != value2.trim()) return false;
      } else if (value1 != value2) {
        return false;
      }
    }

    return true;
  }
}

/// Mixin to add auto-save capabilities to StatefulWidgets
mixin AutoSaveMixin on State {
  late String autoSaveId;
  final AutoSaveService _autoSaveService = AutoSaveService();

  @override
  void initState() {
    super.initState();
    autoSaveId = _generateAutoSaveId();
  }

  @override
  void dispose() {
    _autoSaveService.dispose(autoSaveId);
    super.dispose();
  }

  /// Override this to provide initial values for auto-save
  Map<String, dynamic> getInitialAutoSaveValues();

  /// Override this to provide current values for auto-save
  Map<String, dynamic> getCurrentAutoSaveValues();

  /// Initialize auto-save with current values
  void initializeAutoSave() {
    _autoSaveService.initializeAutoSave(autoSaveId, getInitialAutoSaveValues());
  }

  /// Update auto-save values
  void updateAutoSave() {
    _autoSaveService.updateValues(autoSaveId, getCurrentAutoSaveValues());
  }

  /// Check if there are unsaved changes
  bool get hasUnsavedChanges => _autoSaveService.hasUnsavedChanges(autoSaveId);

  /// Get changed fields
  List<String> get changedFields =>
      _autoSaveService.getChangedFields(autoSaveId);

  /// Load draft
  Future<Map<String, dynamic>?> loadDraft() =>
      _autoSaveService.loadDraft(autoSaveId);

  /// Clear draft
  Future<void> clearDraft() => _autoSaveService.clearDraft(autoSaveId);

  /// Check if draft exists
  Future<bool> hasDraft() => _autoSaveService.hasDraft(autoSaveId);

  /// Mark changes as saved
  void markAsSaved() => _autoSaveService.markAsSaved(autoSaveId);

  String _generateAutoSaveId() {
    return '${T.toString()}_${DateTime.now().millisecondsSinceEpoch}';
  }
}
