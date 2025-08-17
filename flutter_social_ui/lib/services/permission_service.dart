import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum PermissionType { camera, microphone, photos, storage, notifications }

enum PermissionStatus {
  granted,
  denied,
  permanentlyDenied,
  restricted,
  unknown,
}

class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  static const MethodChannel _channel = MethodChannel('quanta/permissions');

  /// Request a specific permission
  static Future<PermissionStatus> requestPermission(
    PermissionType permission,
  ) async {
    try {
      final String result = await _channel.invokeMethod('requestPermission', {
        'permission': permission.name,
      });
      return _parsePermissionStatus(result);
    } on PlatformException catch (e) {
      debugPrint(
        'Error requesting permission ${permission.name}: ${e.message}',
      );
      return PermissionStatus.unknown;
    }
  }

  /// Check the status of a specific permission
  static Future<PermissionStatus> checkPermission(
    PermissionType permission,
  ) async {
    try {
      final String result = await _channel.invokeMethod('checkPermission', {
        'permission': permission.name,
      });
      return _parsePermissionStatus(result);
    } on PlatformException catch (e) {
      debugPrint('Error checking permission ${permission.name}: ${e.message}');
      return PermissionStatus.unknown;
    }
  }

  /// Request multiple permissions at once
  static Future<Map<PermissionType, PermissionStatus>>
  requestMultiplePermissions(List<PermissionType> permissions) async {
    final Map<PermissionType, PermissionStatus> results = {};

    for (final permission in permissions) {
      results[permission] = await requestPermission(permission);
    }

    return results;
  }

  /// Check if a permission is granted
  static Future<bool> isPermissionGranted(PermissionType permission) async {
    final status = await checkPermission(permission);
    return status == PermissionStatus.granted;
  }

  /// Check if a permission is permanently denied
  static Future<bool> isPermissionPermanentlyDenied(
    PermissionType permission,
  ) async {
    final status = await checkPermission(permission);
    return status == PermissionStatus.permanentlyDenied;
  }

  /// Open app settings (useful when permission is permanently denied)
  static Future<bool> openAppSettings() async {
    try {
      final bool result = await _channel.invokeMethod('openAppSettings');
      return result;
    } on PlatformException catch (e) {
      debugPrint('Error opening app settings: ${e.message}');
      return false;
    }
  }

  /// Request camera permission with user-friendly handling
  static Future<bool> requestCameraPermission() async {
    final status = await requestPermission(PermissionType.camera);
    return status == PermissionStatus.granted;
  }

  /// Request microphone permission with user-friendly handling
  static Future<bool> requestMicrophonePermission() async {
    final status = await requestPermission(PermissionType.microphone);
    return status == PermissionStatus.granted;
  }

  /// Request photo library permission with user-friendly handling
  static Future<bool> requestPhotosPermission() async {
    final status = await requestPermission(PermissionType.photos);
    return status == PermissionStatus.granted;
  }

  /// Request all media permissions needed for content creation
  static Future<Map<PermissionType, bool>> requestMediaPermissions() async {
    final permissions = [
      PermissionType.camera,
      PermissionType.microphone,
      PermissionType.photos,
    ];

    final results = await requestMultiplePermissions(permissions);

    return results.map(
      (key, value) => MapEntry(key, value == PermissionStatus.granted),
    );
  }

  /// Get user-friendly permission name
  static String getPermissionName(PermissionType permission) {
    switch (permission) {
      case PermissionType.camera:
        return 'Camera';
      case PermissionType.microphone:
        return 'Microphone';
      case PermissionType.photos:
        return 'Photo Library';
      case PermissionType.storage:
        return 'Storage';
      case PermissionType.notifications:
        return 'Notifications';
    }
  }

  /// Get user-friendly permission description
  static String getPermissionDescription(PermissionType permission) {
    switch (permission) {
      case PermissionType.camera:
        return 'Take photos and record videos for your posts';
      case PermissionType.microphone:
        return 'Record audio for your videos and voice messages';
      case PermissionType.photos:
        return 'Select and share photos and videos from your library';
      case PermissionType.storage:
        return 'Save and access your content';
      case PermissionType.notifications:
        return 'Receive notifications about likes, comments, and messages';
    }
  }

  static PermissionStatus _parsePermissionStatus(String status) {
    switch (status.toLowerCase()) {
      case 'granted':
        return PermissionStatus.granted;
      case 'denied':
        return PermissionStatus.denied;
      case 'permanently_denied':
        return PermissionStatus.permanentlyDenied;
      case 'restricted':
        return PermissionStatus.restricted;
      default:
        return PermissionStatus.unknown;
    }
  }
}

/// Extension to make permission handling more convenient
extension PermissionTypeExtension on PermissionType {
  String get displayName => PermissionService.getPermissionName(this);
  String get description => PermissionService.getPermissionDescription(this);

  Future<PermissionStatus> get status =>
      PermissionService.checkPermission(this);
  Future<PermissionStatus> request() =>
      PermissionService.requestPermission(this);
  Future<bool> get isGranted => PermissionService.isPermissionGranted(this);
  Future<bool> get isPermanentlyDenied =>
      PermissionService.isPermissionPermanentlyDenied(this);
}
