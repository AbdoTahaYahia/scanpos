import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'remote_config_service.dart';

/// Result from barcode lookup containing product info.
class BarcodeLookupResult {
  final String name;
  final String? category;
  final String? brand;
  final double? price;

  const BarcodeLookupResult({
    required this.name,
    this.category,
    this.brand,
    this.price,
  });
}

/// Service that uses Gemini AI to identify products by barcode.
/// The API key is fetched securely from Firebase Remote Config.
class BarcodeLookupService {
  final RemoteConfigService _config = RemoteConfigService.instance;

  /// Look up product info by barcode using Gemini AI.
  Future<BarcodeLookupResult?> lookupBarcode(String barcode) async {
    String geminiKey = '';
    try {
      geminiKey = _config.getString('gemini_api_key');
      debugPrint('[BarcodeLookup] Key loaded: ${geminiKey.isNotEmpty ? "YES (${geminiKey.substring(0, 10)}...)" : "EMPTY"}');
    } catch (e) {
      debugPrint('[BarcodeLookup] Failed to read key: $e');
    }

    if (geminiKey.isEmpty) {
      debugPrint('[BarcodeLookup] ❌ No Gemini API key — make sure Remote Config has "gemini_api_key" published');
      return null;
    }

    debugPrint('[BarcodeLookup] 🤖 Looking up $barcode with Gemini AI...');

    try {
      final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-lite:generateContent?key=$geminiKey');

      final prompt = '''
You are a product identification expert. Given a barcode number, identify the product.

Barcode: $barcode

Return ONLY a valid JSON object (no markdown, no code blocks) with these fields:
- "name": Product name (Arabic name if it's commonly known in Arabic, otherwise English)
- "price": Estimated average retail price in Egyptian Pounds (EGP) as a number (no currency symbol). If unknown, use null.
- "category": Product category in English (e.g. "Food", "Beverages", "Skincare", "Electronics", "Toys", "Cleaning", "Dairy", "Snacks")
- "brand": Brand name if known, otherwise null

Example response:
{"name": "بيبسي 330 مل", "price": 15, "category": "Beverages", "brand": "Pepsi"}

If you cannot identify the product at all, return exactly: null
''';

      var response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.1,
            'maxOutputTokens': 256,
          },
        }),
      ).timeout(const Duration(seconds: 12));

      // Handle rate limiting — wait and retry once
      if (response.statusCode == 429) {
        debugPrint('[Gemini] ⏳ Rate limited — waiting 5s and retrying...');
        await Future.delayed(const Duration(seconds: 5));
        response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'contents': [
              {
                'parts': [
                  {'text': prompt}
                ]
              }
            ],
            'generationConfig': {
              'temperature': 0.1,
              'maxOutputTokens': 256,
            },
          }),
        ).timeout(const Duration(seconds: 12));
      }

      if (response.statusCode != 200) {
        debugPrint('[Gemini] HTTP ${response.statusCode}');
        return null;
      }

      final data = json.decode(response.body);
      final candidates = data['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) return null;

      final content = candidates.first['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List<dynamic>?;
      if (parts == null || parts.isEmpty) return null;

      var text = (parts.first['text'] as String?)?.trim() ?? '';
      if (text.isEmpty || text == 'null') return null;

      // Clean up: remove markdown code blocks if present
      text = text
          .replaceAll(RegExp(r'^```json\s*', multiLine: true), '')
          .replaceAll(RegExp(r'^```\s*', multiLine: true), '')
          .trim();

      if (text == 'null') return null;

      final productData = json.decode(text) as Map<String, dynamic>;

      final name = (productData['name'] as String?)?.trim() ?? '';
      if (name.isEmpty) return null;

      final brand = (productData['brand'] as String?)?.trim();
      final category = (productData['category'] as String?)?.trim();
      final price = productData['price'] != null
          ? (productData['price'] as num).toDouble()
          : null;

      debugPrint('[Gemini] ✅ Found: $name (${price != null ? "EGP $price" : "no price"})');

      return BarcodeLookupResult(
        name: name,
        category: category,
        brand: brand,
        price: price,
      );
    } catch (e) {
      debugPrint('[Gemini] Error: $e');
      return null;
    }
  }
}
