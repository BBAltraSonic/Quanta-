import 'package:flutter/material.dart';
import '../services/avatar_profile_error_handler.dart';
import '../services/avatar_cache_service.dart';
import '../services/avatar_state_sync_service.dart';

/// Demo widget showing how to use the avatar profile error handling system
class AvatarProfileErrorDemo extends StatefulWidget {
  const AvatarProfileErrorDemo({super.key});

  @override
  State<AvatarProfileErrorDemo> createState() => _AvatarProfileErrorDemoState();
}

class _AvatarProfileErrorDemoState extends State<AvatarProfileErrorDemo> {
  final AvatarProfileErrorHandler _errorHandler = AvatarProfileErrorHandler();
  final AvatarCacheService _cacheService = AvatarCacheService();
  final AvatarStateSyncService _syncService = AvatarStateSyncService();

  Widget? _currentErrorWidget;
  String _statusMessage = 'Ready to demonstrate error handling';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Avatar Profile Error Handling Demo')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Error Handling Demo',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(_statusMessage),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton(
                          onPressed: _simulateAvatarNotFound,
                          child: const Text('Avatar Not Found'),
                        ),
                        ElevatedButton(
                          onPressed: _simulatePermissionDenied,
                          child: const Text('Permission Denied'),
                        ),
                        ElevatedButton(
                          onPressed: _simulateNetworkError,
                          child: const Text('Network Error'),
                        ),
                        ElevatedButton(
                          onPressed: _simulateCacheError,
                          child: const Text('Cache Error'),
                        ),
                        ElevatedButton(
                          onPressed: _simulateStateSyncError,
                          child: const Text('State Sync Error'),
                        ),
                        ElevatedButton(
                          onPressed: _simulateDatabaseError,
                          child: const Text('Database Error'),
                        ),
                        ElevatedButton(
                          onPressed: _simulateAuthRequired,
                          child: const Text('Auth Required'),
                        ),
                        ElevatedButton(
                          onPressed: _simulateOwnershipError,
                          child: const Text('Ownership Error'),
                        ),
                        ElevatedButton(
                          onPressed: _simulateInvalidData,
                          child: const Text('Invalid Data'),
                        ),
                        ElevatedButton(
                          onPressed: _simulateRateLimit,
                          child: const Text('Rate Limited'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cache Statistics',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    _buildCacheStats(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sync Service Status',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    _buildSyncStatus(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_currentErrorWidget != null) ...[
              Text(
                'Error Widget Preview:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Expanded(child: Card(child: _currentErrorWidget!)),
            ] else ...[
              const Expanded(
                child: Card(
                  child: Center(
                    child: Text(
                      'Click a button above to see error handling in action',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCacheStats() {
    final stats = _cacheService.getCacheStats();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Hit Rate: ${stats['hitRate'].toStringAsFixed(1)}%'),
        Text('Total Requests: ${stats['totalRequests']}'),
        Text('Cache Hits: ${stats['hits']}'),
        Text('Cache Misses: ${stats['misses']}'),
        Text('Evictions: ${stats['evictions']}'),
        Text('Health: ${_cacheService.isHealthy ? 'Healthy' : 'Unhealthy'}'),
      ],
    );
  }

  Widget _buildSyncStatus() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Pending Operations: ${_syncService.pendingOperationsCount}'),
        Text('Has Pending: ${_syncService.hasPendingOperations}'),
        Text(
          'Available Snapshots: ${_syncService.getAvailableSnapshots().length}',
        ),
        Text('State Consistent: ${_syncService.validateStateConsistency()}'),
      ],
    );
  }

  void _simulateAvatarNotFound() {
    final exception = AvatarProfileErrorHandler.avatarNotFound(
      'demo-avatar-123',
    );
    _showError(exception, 'Simulated avatar not found error');
  }

  void _simulatePermissionDenied() {
    final exception = AvatarProfileErrorHandler.permissionDenied(
      'view avatar profile',
    );
    _showError(exception, 'Simulated permission denied error');
  }

  void _simulateNetworkError() {
    final exception = AvatarProfileErrorHandler.networkError(
      'loading avatar data',
    );
    _showError(exception, 'Simulated network error');
  }

  void _simulateCacheError() {
    final exception = AvatarProfileErrorHandler.cacheError(
      'retrieving cached avatar',
    );
    _showError(exception, 'Simulated cache error');
  }

  void _simulateStateSyncError() {
    final exception = AvatarProfileErrorHandler.stateSyncError(
      'avatar state mismatch',
    );
    _showError(exception, 'Simulated state sync error');
  }

  void _simulateDatabaseError() {
    final exception = AvatarProfileErrorHandler.databaseError(
      'querying avatar table',
    );
    _showError(exception, 'Simulated database error');
  }

  void _simulateAuthRequired() {
    final exception = AvatarProfileErrorHandler.authenticationRequired();
    _showError(exception, 'Simulated authentication required error');
  }

  void _simulateOwnershipError() {
    final exception = AvatarProfileErrorHandler.avatarOwnershipError(
      'demo-avatar-123',
    );
    _showError(exception, 'Simulated ownership error');
  }

  void _simulateInvalidData() {
    final exception = AvatarProfileErrorHandler.invalidAvatarData(
      'malformed JSON response',
    );
    _showError(exception, 'Simulated invalid data error');
  }

  void _simulateRateLimit() {
    final exception = AvatarProfileErrorHandler.rateLimitExceeded();
    _showError(exception, 'Simulated rate limit error');
  }

  void _showError(AvatarProfileException exception, String statusMessage) {
    setState(() {
      _statusMessage = statusMessage;
      _currentErrorWidget = _errorHandler.handleError(
        exception,
        onRetry: () {
          _handleRetry(exception.type.toString());
        },
        onRefresh: () {
          _handleRefresh();
        },
      );
    });
  }

  void _handleRetry(String errorType) {
    setState(() {
      _statusMessage = 'Retry attempted for $errorType';
      _currentErrorWidget = null;
    });

    // Simulate retry delay
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _statusMessage = 'Retry completed - error resolved';
        });
      }
    });
  }

  void _handleRefresh() {
    setState(() {
      _statusMessage = 'Refresh initiated - clearing cache and reloading';
      _currentErrorWidget = null;
    });

    // Simulate cache refresh
    _cacheService.clearAll();

    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _statusMessage = 'Refresh completed - data reloaded';
        });
      }
    });
  }
}
