import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Service for managing device identification
/// Generates and persists a unique device ID for anonymous tracking
class DeviceService {
  static const String _deviceIdKey = 'skilloper_device_id';
  static final DeviceService _instance = DeviceService._internal();

  factory DeviceService() => _instance;
  DeviceService._internal();

  String? _cachedDeviceId;

  /// Gets the device ID, generating one if it doesn't exist
  Future<String> getDeviceId() async {
    // Return cached value if available
    if (_cachedDeviceId != null) {
      return _cachedDeviceId!;
    }

    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString(_deviceIdKey);

    if (deviceId == null || deviceId.isEmpty) {
      // Generate a new UUID
      deviceId = const Uuid().v4();
      await prefs.setString(_deviceIdKey, deviceId);
    }

    _cachedDeviceId = deviceId;
    return deviceId;
  }

  /// Clears the cached device ID (useful for testing)
  void clearCache() {
    _cachedDeviceId = null;
  }
}
