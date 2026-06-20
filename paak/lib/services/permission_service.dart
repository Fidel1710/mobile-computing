import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  /// Request all BLE and Location permissions required for scanning and advertising.
  static Future<bool> requestBlePermissions() async {
    if (!Platform.isAndroid) return true;

    // We request location and Android 12+ BLE permissions
    final List<Permission> permissions = [
      Permission.location,
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
    ];

    final Map<Permission, PermissionStatus> statuses = await permissions.request();

    bool allGranted = true;
    statuses.forEach((permission, status) {
      if (!status.isGranted) {
        allGranted = false;
      }
    });

    return allGranted;
  }

  /// Check whether all necessary permissions are granted.
  static Future<bool> arePermissionsGranted() async {
    if (!Platform.isAndroid) return true;

    final List<Permission> permissions = [
      Permission.location,
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
    ];

    for (var permission in permissions) {
      final status = await permission.status;
      if (!status.isGranted) {
        return false;
      }
    }
    return true;
  }

  /// Helper to open the app system settings.
  static Future<bool> openSystemSettings() async {
    return await openAppSettings();
  }
}
