
import '../models/avatar_model.dart';
import '../store/app_state.dart';
import '../services/auth_service.dart';
import '../services/avatar_service.dart';
import '../services/avatar_profile_error_handler.dart';

/// State snapshot for rollback capability
class AvatarStateSnapshot {
  final Map<String, AvatarModel> avatars;
  final AvatarModel? activeAvatar;
  final Map<String, ProfileViewMode> avatarViewModes;
  final Map<String, List<String>> userAvatars;
  final DateTime timestamp;

  AvatarStateSnapshot({
    required this.avatars,
    required this.activeAvatar,
    required this.avatarViewModes,
    required this.userAvatars,
    required this.timestamp,
  });

  AvatarStateSnapshot copyWith({
    Map<String, AvatarModel>? avatars,
    AvatarModel? activeAvatar,
    Map<String, ProfileViewMode>? avatarViewModes,
    Map<String, List<String>>? userAvatars,
  }) {
    return AvatarStateSnapshot(
      avatars: avatars ?? Map.from(this.avatars),
      activeAvatar: activeAvatar ?? this.activeAvatar,
      avatarViewModes: avatarViewModes ?? Map.from(this.avatarViewModes),
      userAvatars: userAvatars ?? Map.from(this.userAvatars),
      timestamp: DateTime.now(),
    );
  }
}

/// Service for managing avatar state synchronization with rollback capability
class AvatarStateSyncService {
  static final AvatarStateSyncService _instance =
      AvatarStateSyncService._internal();
  factory AvatarStateSyncService() => _instance;
  AvatarStateSyncService._internal();

  final AppState _appState = AppState();
  final AuthService _authService = AuthService();
  final AvatarService _avatarService = AvatarService();
  final AvatarProfileErrorHandler _errorHandler = AvatarProfileErrorHandler();

  // State snapshots for rollback
  final List<AvatarStateSnapshot> _stateHistory = [];
  static const int _maxHistorySize = 10;

  // Pending operations tracking
  final Map<String, DateTime> _pendingOperations = {};
  static const Duration _operationTimeout = Duration(seconds: 30);

  /// Create a snapshot of current avatar state
  AvatarStateSnapshot _createSnapshot() {
    // Get current user avatars mapping
    final userAvatarsMap = <String, List<String>>{};
    if (_appState.currentUserId != null) {
      final currentUserAvatars = _appState.getUserAvatars(
        _appState.currentUserId!,
      );
      userAvatarsMap[_appState.currentUserId!] = currentUserAvatars
          .map((a) => a.id)
          .toList();
    }

    // Get current avatar view modes (we'll need to track these separately)
    final avatarViewModes = <String, ProfileViewMode>{};
    for (final avatarId in _appState.avatars.keys) {
      avatarViewModes[avatarId] = _appState.getAvatarViewMode(avatarId);
    }

    return AvatarStateSnapshot(
      avatars: Map.from(_appState.avatars),
      activeAvatar: _appState.activeAvatar,
      avatarViewModes: avatarViewModes,
      userAvatars: userAvatarsMap,
      timestamp: DateTime.now(),
    );
  }

  /// Save current state snapshot for potential rollback
  void _saveSnapshot() {
    final snapshot = _createSnapshot();
    _stateHistory.add(snapshot);

    // Keep only the last N snapshots
    if (_stateHistory.length > _maxHistorySize) {
      _stateHistory.removeAt(0);
    }
  }

  /// Rollback to the most recent snapshot
  Future<bool> rollbackToLastSnapshot() async {
    if (_stateHistory.isEmpty) {
      _errorHandler.logError('No snapshots available for rollback');
      return false;
    }

    try {
      final snapshot = _stateHistory.last;
      await _restoreSnapshot(snapshot);
      _stateHistory.removeLast(); // Remove the snapshot we just restored to
      return true;
    } catch (e) {
      _errorHandler.logError(e, context: 'rollback');
      return false;
    }
  }

  /// Rollback to a specific snapshot by timestamp
  Future<bool> rollbackToSnapshot(DateTime timestamp) async {
    final snapshotIndex = _stateHistory.indexWhere(
      (snapshot) => snapshot.timestamp.isAtSameMomentAs(timestamp),
    );

    if (snapshotIndex == -1) {
      _errorHandler.logError('Snapshot not found for timestamp: $timestamp');
      return false;
    }

    try {
      final snapshot = _stateHistory[snapshotIndex];
      await _restoreSnapshot(snapshot);

      // Remove snapshots after the restored one
      _stateHistory.removeRange(snapshotIndex, _stateHistory.length);
      return true;
    } catch (e) {
      _errorHandler.logError(e, context: 'rollback to timestamp');
      return false;
    }
  }

  /// Restore state from a snapshot
  Future<void> _restoreSnapshot(AvatarStateSnapshot snapshot) async {
    // Restore avatars
    for (final avatar in snapshot.avatars.values) {
      _appState.setAvatar(avatar);
    }

    // Restore active avatar
    if (snapshot.activeAvatar != null) {
      _appState.setActiveAvatar(snapshot.activeAvatar);
    }

    // Restore view modes
    for (final entry in snapshot.avatarViewModes.entries) {
      _appState.setAvatarViewMode(entry.key, entry.value);
    }

    // Note: User avatars mapping is maintained automatically by setAvatar calls
  }

  /// Synchronize avatar state with remote database
  Future<void> syncAvatarState(String userId) async {
    final operationId = 'sync_avatar_state_$userId';

    try {
      _saveSnapshot(); // Save current state before sync
      _startOperation(operationId);

      // Get fresh avatar data from database
      final avatars = await _avatarService.getUserAvatars(userId);
      final activeAvatar = await _getActiveAvatarFromDatabase(userId);

      // Update app state with fresh data
      for (final avatar in avatars) {
        _appState.setAvatar(avatar);
      }

      if (activeAvatar != null) {
        _appState.setActiveAvatar(activeAvatar);
      }

      _completeOperation(operationId);
    } catch (e) {
      _failOperation(operationId);

      // Attempt rollback on sync failure
      final rollbackSuccess = await rollbackToLastSnapshot();

      if (rollbackSuccess) {
        throw AvatarProfileErrorHandler.stateSyncError(
          'Sync failed but state was rolled back successfully',
          e,
        );
      } else {
        throw AvatarProfileErrorHandler.stateSyncError(
          'Sync failed and rollback also failed',
          e,
        );
      }
    }
  }

  /// Optimistically update avatar state with rollback on failure
  Future<void> optimisticAvatarUpdate(
    String avatarId,
    AvatarModel updatedAvatar,
    Future<void> Function() remoteUpdate,
  ) async {
    final operationId = 'optimistic_update_$avatarId';

    try {
      _saveSnapshot(); // Save current state before update
      _startOperation(operationId);

      // Apply optimistic update
      _appState.setAvatar(updatedAvatar);

      // Attempt remote update
      await remoteUpdate();

      _completeOperation(operationId);
    } catch (e) {
      _failOperation(operationId);

      // Rollback on failure
      final rollbackSuccess = await rollbackToLastSnapshot();

      if (rollbackSuccess) {
        throw AvatarProfileErrorHandler.stateSyncError(
          'Avatar update failed but state was rolled back',
          e,
        );
      } else {
        throw AvatarProfileErrorHandler.stateSyncError(
          'Avatar update failed and rollback also failed',
          e,
        );
      }
    }
  }

  /// Optimistically set active avatar with rollback on failure
  Future<void> optimisticSetActiveAvatar(
    String userId,
    AvatarModel avatar,
    Future<void> Function() remoteUpdate,
  ) async {
    final operationId = 'optimistic_set_active_$userId';

    try {
      _saveSnapshot(); // Save current state before update
      _startOperation(operationId);

      // Apply optimistic update
      _appState.setActiveAvatarForUser(userId, avatar);

      // Attempt remote update
      await remoteUpdate();

      _completeOperation(operationId);
    } catch (e) {
      _failOperation(operationId);

      // Rollback on failure
      final rollbackSuccess = await rollbackToLastSnapshot();

      if (rollbackSuccess) {
        throw AvatarProfileErrorHandler.stateSyncError(
          'Set active avatar failed but state was rolled back',
          e,
        );
      } else {
        throw AvatarProfileErrorHandler.stateSyncError(
          'Set active avatar failed and rollback also failed',
          e,
        );
      }
    }
  }

  /// Get active avatar from database
  Future<AvatarModel?> _getActiveAvatarFromDatabase(String userId) async {
    try {
      final userResponse = await _authService.supabase
          .from('users')
          .select('active_avatar_id')
          .eq('id', userId)
          .single();

      final activeAvatarId = userResponse['active_avatar_id'] as String?;
      if (activeAvatarId == null) {
        return null;
      }

      return await _avatarService.getAvatarById(activeAvatarId);
    } catch (e) {
      _errorHandler.logError(e, context: 'get active avatar from database');
      return null;
    }
  }

  /// Start tracking an operation
  void _startOperation(String operationId) {
    _pendingOperations[operationId] = DateTime.now();
  }

  /// Mark operation as completed
  void _completeOperation(String operationId) {
    _pendingOperations.remove(operationId);
  }

  /// Mark operation as failed
  void _failOperation(String operationId) {
    _pendingOperations.remove(operationId);
  }

  /// Check for timed out operations
  void checkForTimeouts() {
    final now = DateTime.now();
    final timedOutOperations = <String>[];

    for (final entry in _pendingOperations.entries) {
      if (now.difference(entry.value) > _operationTimeout) {
        timedOutOperations.add(entry.key);
      }
    }

    for (final operationId in timedOutOperations) {
      _failOperation(operationId);
      _errorHandler.logError(
        'Operation timed out: $operationId',
        context: 'timeout check',
      );
    }
  }

  /// Get pending operations count
  int get pendingOperationsCount => _pendingOperations.length;

  /// Check if there are any pending operations
  bool get hasPendingOperations => _pendingOperations.isNotEmpty;

  /// Get list of pending operation IDs
  List<String> get pendingOperationIds => _pendingOperations.keys.toList();

  /// Clear all state history (use with caution)
  void clearStateHistory() {
    _stateHistory.clear();
  }

  /// Get available snapshots for rollback
  List<DateTime> getAvailableSnapshots() {
    return _stateHistory.map((snapshot) => snapshot.timestamp).toList();
  }

  /// Force sync with conflict resolution
  Future<void> forceSyncWithConflictResolution(String userId) async {
    try {
      _saveSnapshot(); // Save current state

      // Get both local and remote state
      final localAvatars = _appState.getUserAvatars(userId);
      final remoteAvatars = await _avatarService.getUserAvatars(userId);

      // Simple conflict resolution: remote wins
      for (final remoteAvatar in remoteAvatars) {
        _appState.setAvatar(remoteAvatar);
      }

      // Remove local avatars that don't exist remotely
      for (final localAvatar in localAvatars) {
        final existsRemotely = remoteAvatars.any((a) => a.id == localAvatar.id);
        if (!existsRemotely) {
          _appState.removeAvatar(localAvatar.id);
        }
      }

      // Update active avatar
      final remoteActiveAvatar = await _getActiveAvatarFromDatabase(userId);
      if (remoteActiveAvatar != null) {
        _appState.setActiveAvatar(remoteActiveAvatar);
      }
    } catch (e) {
      // Rollback on any error
      await rollbackToLastSnapshot();
      throw AvatarProfileErrorHandler.stateSyncError('Force sync failed', e);
    }
  }

  /// Validate state consistency
  bool validateStateConsistency() {
    try {
      // Check if active avatar exists in avatars map
      final activeAvatar = _appState.activeAvatar;
      if (activeAvatar != null &&
          !_appState.avatars.containsKey(activeAvatar.id)) {
        return false;
      }

      // Check if current user's avatars are consistent
      if (_appState.currentUserId != null) {
        final userAvatars = _appState.getUserAvatars(_appState.currentUserId!);

        for (final avatar in userAvatars) {
          if (avatar.ownerUserId != _appState.currentUserId) {
            return false;
          }
        }
      }

      return true;
    } catch (e) {
      _errorHandler.logError(e, context: 'state consistency validation');
      return false;
    }
  }
}
