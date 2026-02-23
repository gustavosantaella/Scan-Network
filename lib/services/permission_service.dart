import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  /// Requests all permissions the app needs to function on mobile.
  ///
  /// On Android: requests ACCESS_FINE_LOCATION (required for Wi-Fi info on
  /// Android 8.1+). Without it, getWifiIP() returns null.
  ///
  /// On iOS: the Local Network permission dialog is triggered automatically
  /// the first time the app makes a network connection. We request location
  /// here as a best-effort (used by network_info_plus for Wi-Fi SSID on iOS).
  ///
  /// Returns true if all critical permissions were granted.
  static Future<bool> requestNetworkPermissions() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      // Desktop platforms don't need runtime permission requests
      return true;
    }

    if (Platform.isAndroid) {
      final status = await Permission.locationWhenInUse.request();
      return status.isGranted;
    }

    if (Platform.isIOS) {
      // On iOS, network_info_plus needs location permission for SSID.
      // The local network permission dialog appears automatically on first
      // TCP/UDP connection — no explicit request needed from our side.
      final status = await Permission.locationWhenInUse.request();
      return status.isGranted || status.isDenied; // Non-fatal on iOS
    }

    return true;
  }

  /// Shows the app settings screen so the user can grant a denied permission.
  static Future<void> openSettings() async {
    await openAppSettings();
  }
}
