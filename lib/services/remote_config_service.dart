import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

/// Singleton service for securely fetching API keys and config values
/// from Firebase Remote Config — keeps secrets off the client code.
class RemoteConfigService {
  RemoteConfigService._();
  static final RemoteConfigService _instance = RemoteConfigService._();
  static RemoteConfigService get instance => _instance;

  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;
  bool _initialized = false;

  // ─── Remote Config Keys ─────────────────────────────────────────
  static const String _barcodeLookupApiKey = 'barcode_lookup_api_key';
  static const String _barcodeLookupProvider = 'barcode_lookup_provider';

  /// Initialize Remote Config with defaults and fetch latest values.
  /// Call once at app startup (after Firebase.initializeApp).
  Future<void> init() async {
    if (_initialized) return;

    try {
      // Set defaults (used when no value exists in Remote Config yet)
      await _remoteConfig.setDefaults({
        _barcodeLookupApiKey: '',
        _barcodeLookupProvider: 'openfoodfacts', // free, no key needed
      });

      // Configure fetch settings
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        // In debug, use short interval; in production, use 12 hours
        minimumFetchInterval: kDebugMode
            ? const Duration(minutes: 1)
            : const Duration(hours: 12),
      ));

      // Fetch and activate latest values from Firebase
      await _remoteConfig.fetchAndActivate();

      _initialized = true;
      debugPrint('[RemoteConfig] Initialized successfully');
    } catch (e) {
      // Non-fatal — app works with defaults if fetch fails
      debugPrint('[RemoteConfig] Init failed (using defaults): $e');
      _initialized = true;
    }
  }

  // ─── Getters ────────────────────────────────────────────────────

  /// Get the barcode lookup API key (empty string = use free API)
  String get barcodeLookupApiKey =>
      _remoteConfig.getString(_barcodeLookupApiKey);

  /// Get the barcode lookup provider name
  /// Values: 'openfoodfacts' (default/free), 'upcitemdb', 'barcodelookup'
  String get barcodeLookupProvider =>
      _remoteConfig.getString(_barcodeLookupProvider);

  /// Check if a paid barcode API is configured
  bool get hasPaidBarcodeApi => barcodeLookupApiKey.isNotEmpty;

  /// Generic getter for any Remote Config string value
  String getString(String key) => _remoteConfig.getString(key);

  /// Generic getter for any Remote Config bool value
  bool getBool(String key) => _remoteConfig.getBool(key);

  /// Generic getter for any Remote Config int value
  int getInt(String key) => _remoteConfig.getInt(key);
}
