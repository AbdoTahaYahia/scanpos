import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'remote_config_service.dart';

/// Result from barcode lookup containing product info from the internet.
class BarcodeLookupResult {
  final String name;
  final String? category;
  final String? brand;

  const BarcodeLookupResult({
    required this.name,
    this.category,
    this.brand,
  });
}

/// Service that looks up product information from online databases
/// using the barcode number.
///
/// Supports multiple providers:
/// - **Open Food Facts** (default, free, no API key)
/// - **UPC Item DB** (API key from Firebase Remote Config)
/// - **Barcode Lookup** (API key from Firebase Remote Config)
///
/// API keys are fetched securely from Firebase Remote Config,
/// never hardcoded in the app.
class BarcodeLookupService {
  final RemoteConfigService _config = RemoteConfigService.instance;

  /// Look up product info by barcode — automatically selects
  /// the right API based on Remote Config settings.
  Future<BarcodeLookupResult?> lookupBarcode(String barcode) async {
    // Check if a paid API is configured via Remote Config
    if (_config.hasPaidBarcodeApi) {
      final provider = _config.barcodeLookupProvider;
      final apiKey = _config.barcodeLookupApiKey;

      switch (provider) {
        case 'upcitemdb':
          return _lookupUpcItemDb(barcode, apiKey);
        case 'barcodelookup':
          return _lookupBarcodeLookupApi(barcode, apiKey);
        default:
          // Unknown provider — fallback to free API
          break;
      }
    }

    // Default: use free Open Food Facts API (no key needed)
    return _lookupOpenFoodFacts(barcode);
  }

  // ─── Open Food Facts (Free, No Key) ─────────────────────────────

  static const _offBaseUrl = 'https://world.openfoodfacts.org/api/v2/product';

  Future<BarcodeLookupResult?> _lookupOpenFoodFacts(String barcode) async {
    try {
      final url = Uri.parse(
          '$_offBaseUrl/$barcode?fields=product_name,product_name_ar,brands,categories');
      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'ScanPos/1.0 (Flutter POS App)',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return null;

      final data = json.decode(response.body);
      if (data['status'] != 1) return null;

      final product = data['product'] as Map<String, dynamic>?;
      if (product == null) return null;

      // Try Arabic name first, then English
      final name =
          (product['product_name_ar'] as String?)?.trim().isNotEmpty == true
              ? product['product_name_ar'] as String
              : (product['product_name'] as String?) ?? '';

      if (name.isEmpty) return null;

      // Build display name with brand
      final brand = (product['brands'] as String?)?.trim();
      final displayName =
          brand != null && brand.isNotEmpty && !name.contains(brand)
              ? '$name - $brand'
              : name;

      // Get first category
      final categoriesRaw = product['categories'] as String?;
      String? category;
      if (categoriesRaw != null && categoriesRaw.isNotEmpty) {
        final cats = categoriesRaw
            .split(',')
            .map((c) => c.trim())
            .where((c) => c.isNotEmpty)
            .toList();
        if (cats.isNotEmpty) {
          category = cats.first;
          if (category.contains(':')) {
            category = category.split(':').last.trim();
          }
          if (category.isNotEmpty) {
            category = category[0].toUpperCase() + category.substring(1);
          }
        }
      }

      return BarcodeLookupResult(
        name: displayName,
        category: category,
        brand: brand,
      );
    } catch (e) {
      debugPrint('[BarcodeLookup] OpenFoodFacts error: $e');
      return null;
    }
  }

  // ─── UPC Item DB (Paid, API Key from Remote Config) ─────────────

  Future<BarcodeLookupResult?> _lookupUpcItemDb(
      String barcode, String apiKey) async {
    try {
      final url = Uri.parse('https://api.upcitemdb.com/prod/trial/lookup?upc=$barcode');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'user_key': apiKey,
          'key_type': '3scale',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        // Fallback to free API
        return _lookupOpenFoodFacts(barcode);
      }

      final data = json.decode(response.body);
      final items = data['items'] as List<dynamic>?;
      if (items == null || items.isEmpty) return null;

      final item = items.first as Map<String, dynamic>;
      final title = (item['title'] as String?)?.trim() ?? '';
      if (title.isEmpty) return null;

      final brand = (item['brand'] as String?)?.trim();
      final category = (item['category'] as String?)?.trim();

      return BarcodeLookupResult(
        name: title,
        category: category,
        brand: brand,
      );
    } catch (e) {
      debugPrint('[BarcodeLookup] UPCItemDB error: $e — falling back to OFF');
      return _lookupOpenFoodFacts(barcode);
    }
  }

  // ─── Barcode Lookup API (Paid, API Key from Remote Config) ──────

  Future<BarcodeLookupResult?> _lookupBarcodeLookupApi(
      String barcode, String apiKey) async {
    try {
      final url = Uri.parse(
          'https://api.barcodelookup.com/v3/products?barcode=$barcode&formatted=y&key=$apiKey');
      final response = await http.get(url).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        return _lookupOpenFoodFacts(barcode);
      }

      final data = json.decode(response.body);
      final products = data['products'] as List<dynamic>?;
      if (products == null || products.isEmpty) return null;

      final product = products.first as Map<String, dynamic>;
      final title = (product['title'] as String?)?.trim() ?? '';
      if (title.isEmpty) return null;

      final brand = (product['brand'] as String?)?.trim();
      final category = (product['category'] as String?)?.trim();

      return BarcodeLookupResult(
        name: title,
        category: category,
        brand: brand,
      );
    } catch (e) {
      debugPrint('[BarcodeLookup] BarcodeLookup API error: $e — falling back to OFF');
      return _lookupOpenFoodFacts(barcode);
    }
  }
}
