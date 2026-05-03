import 'dart:convert';
import 'package:http/http.dart' as http;

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
/// using the barcode number. Uses Open Food Facts API (free, no key needed).
class BarcodeLookupService {
  static const _baseUrl = 'https://world.openfoodfacts.org/api/v2/product';

  /// Look up product info by barcode from Open Food Facts
  Future<BarcodeLookupResult?> lookupBarcode(String barcode) async {
    try {
      final url = Uri.parse('$_baseUrl/$barcode?fields=product_name,product_name_ar,brands,categories');
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
      final name = (product['product_name_ar'] as String?)?.trim().isNotEmpty == true
          ? product['product_name_ar'] as String
          : (product['product_name'] as String?) ?? '';

      if (name.isEmpty) return null;

      // Build display name with brand
      final brand = (product['brands'] as String?)?.trim();
      final displayName = brand != null && brand.isNotEmpty && !name.contains(brand)
          ? '$name - $brand'
          : name;

      // Get first category
      final categoriesRaw = product['categories'] as String?;
      String? category;
      if (categoriesRaw != null && categoriesRaw.isNotEmpty) {
        final cats = categoriesRaw.split(',').map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
        if (cats.isNotEmpty) {
          category = cats.first;
          // Clean up: remove language prefix like "en:" or "ar:"
          if (category.contains(':')) {
            category = category.split(':').last.trim();
          }
          // Capitalize first letter
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
      // Network error, timeout, etc — just return null
      return null;
    }
  }
}
