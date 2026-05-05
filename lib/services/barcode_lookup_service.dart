import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

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

/// Service that looks up product information using a Web Search Scraper.
/// This approach is 100% free and requires no API keys.
class BarcodeLookupService {
  // ── In-memory cache ─────────────────────────────────────────────
  final Map<String, BarcodeLookupResult?> _cache = {};

  /// Look up product info by barcode — tries multiple free APIs.
  Future<BarcodeLookupResult?> lookupBarcode(String barcode) async {
    // Return cached result immediately
    if (_cache.containsKey(barcode)) {
      debugPrint('[Lookup] ⚡ Cache hit for $barcode');
      return _cache[barcode];
    }

    final result = await _searchAllApis(barcode);
    _cache[barcode] = result;
    return result;
  }

  void clearCache() => _cache.clear();

  // ── Search all APIs ─────────────────────────────────────────────

  Future<BarcodeLookupResult?> _searchAllApis(String barcode) async {
    // 1. UPC Item DB — covers ALL product types (100 free/day)
    debugPrint('[Lookup] 🔍 Trying UPC Item DB for: $barcode');
    final upc = await _lookupUpcItemDb(barcode);
    if (upc != null) return upc;

    // 2. All Open *Facts APIs in PARALLEL — much faster than sequential
    debugPrint('[Lookup] 🔍 Trying all Open *Facts APIs in parallel...');
    final openFactsResult = await _lookupAllOpenFacts(barcode);
    if (openFactsResult != null) return openFactsResult;

    // 3. Open Food Facts keyword search
    debugPrint('[Lookup] 🔍 Trying Open Food Facts search...');
    final searchResult = await _searchOpenFoodFacts(barcode);
    if (searchResult != null) return searchResult;

    // 4. Web Search Scraper (Free, no API key needed)
    debugPrint('[Lookup] 🌐 Trying Web Search Fallback...');
    final webResult = await _lookupWebSearch(barcode);
    if (webResult != null) return webResult;

    debugPrint('[Lookup] ❌ Not found via Web Search for barcode: $barcode');
    return null;
  }

  // ═══════════════════════════════════════════════════════════════
  // UPC Item DB (Free Trial — ALL product types)
  // No API key needed. 100 lookups/day.
  // ═══════════════════════════════════════════════════════════════

  Future<BarcodeLookupResult?> _lookupUpcItemDb(String barcode) async {
    try {
      final url = Uri.parse(
          'https://api.upcitemdb.com/prod/trial/lookup?upc=$barcode');
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 8));

      if (response.statusCode == 429) {
        debugPrint('[UPC] ⚠️ Rate limited (429) — daily quota exceeded');
        return null;
      }

      if (response.statusCode != 200) {
        debugPrint('[UPC] HTTP ${response.statusCode}: ${response.body.length > 200 ? response.body.substring(0, 200) : response.body}');
        return null;
      }

      final data = json.decode(response.body);

      // Check for rate-limit in response body (sometimes 200 but with error)
      if (data['code'] == 'EXCEEDED' || data['code'] == 'INVALID') {
        debugPrint('[UPC] ⚠️ API responded: ${data['code']} — ${data['message'] ?? 'no message'}');
        return null;
      }

      final items = data['items'] as List<dynamic>?;
      if (items == null || items.isEmpty) {
        debugPrint('[UPC] No items found for $barcode');
        return null;
      }

      final item = items.first as Map<String, dynamic>;
      final title = (item['title'] as String?)?.trim() ?? '';
      if (title.isEmpty) return null;

      final brand = (item['brand'] as String?)?.trim();
      final category = (item['category'] as String?)?.trim();

      // Try to get price from offers
      double? price;
      final offers = item['offers'] as List<dynamic>?;
      if (offers != null && offers.isNotEmpty) {
        for (final offer in offers) {
          final p = offer['price'] as num?;
          if (p != null && p > 0) {
            price = p.toDouble();
            break;
          }
        }
      }

      // Build display name
      final displayName =
          brand != null && brand.isNotEmpty && !title.contains(brand)
              ? '$title - $brand'
              : title;

      debugPrint('[UPC] ✅ Found: $displayName');
      return BarcodeLookupResult(
        name: displayName,
        category: _cleanCategory(category),
        brand: brand,
        price: price,
      );
    } catch (e) {
      debugPrint('[UPC] Error: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // Open *Facts APIs — queried in PARALLEL
  // (Food, Beauty, Pet Food, Products)
  // No API key needed. Unlimited lookups.
  // ═══════════════════════════════════════════════════════════════

  /// Fire all Open*Facts lookups in parallel, return the first valid result.
  Future<BarcodeLookupResult?> _lookupAllOpenFacts(String barcode) async {
    try {
      final futures = <Future<BarcodeLookupResult?>>[
        _lookupOpenXFacts(
          barcode,
          'https://world.openfoodfacts.org/api/v2/product',
          'Food',
        ),
        _lookupOpenXFacts(
          barcode,
          'https://world.openbeautyfacts.org/api/v2/product',
          'Beauty',
        ),
        _lookupOpenXFacts(
          barcode,
          'https://world.openpetfoodfacts.org/api/v2/product',
          'Pet Food',
        ),
        _lookupOpenXFacts(
          barcode,
          'https://world.openproductsfacts.org/api/v2/product',
          'Products',
        ),
      ];

      // Wait for all to complete, then pick the first non-null
      final results = await Future.wait(futures);
      for (final result in results) {
        if (result != null) return result;
      }

      debugPrint('[OpenFacts] No results from any Open*Facts DB');
      return null;
    } catch (e) {
      debugPrint('[OpenFacts] Parallel lookup error: $e');
      return null;
    }
  }

  Future<BarcodeLookupResult?> _lookupOpenXFacts(
      String barcode, String baseUrl, String defaultCategory) async {
    try {
      final url = Uri.parse(
          '$baseUrl/$barcode?fields=product_name,product_name_ar,brands,categories');
      final response = await http.get(url, headers: {
        'User-Agent': 'ScanPos/1.0 (Flutter POS App)',
      }).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        debugPrint('[OpenFacts:$defaultCategory] HTTP ${response.statusCode}');
        return null;
      }

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

      final brand = (product['brands'] as String?)?.trim();
      final displayName =
          brand != null && brand.isNotEmpty && !name.contains(brand)
              ? '$name - $brand'
              : name;

      // Extract category
      final categoriesRaw = product['categories'] as String?;
      final category = _extractFirstCategory(categoriesRaw) ?? defaultCategory;

      debugPrint('[OpenFacts:$defaultCategory] ✅ Found: $displayName');
      return BarcodeLookupResult(
        name: displayName,
        category: category,
        brand: brand,
      );
    } catch (e) {
      debugPrint('[OpenFacts:$defaultCategory] Error: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // Open Food Facts Search (keyword search by barcode as fallback)
  // Sometimes a barcode is in the search index but not the direct
  // product endpoint.
  // ═══════════════════════════════════════════════════════════════

  Future<BarcodeLookupResult?> _searchOpenFoodFacts(String barcode) async {
    try {
      final url = Uri.parse(
          'https://world.openfoodfacts.org/cgi/search.pl?search_terms=$barcode&search_simple=1&action=process&json=1&page_size=1&fields=product_name,product_name_ar,brands,categories');
      final response = await http.get(url, headers: {
        'User-Agent': 'ScanPos/1.0 (Flutter POS App)',
      }).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        debugPrint('[OFF-Search] HTTP ${response.statusCode}');
        return null;
      }

      final data = json.decode(response.body);
      final products = data['products'] as List<dynamic>?;
      if (products == null || products.isEmpty) {
        debugPrint('[OFF-Search] No search results for $barcode');
        return null;
      }

      final product = products.first as Map<String, dynamic>;
      final name =
          (product['product_name_ar'] as String?)?.trim().isNotEmpty == true
              ? product['product_name_ar'] as String
              : (product['product_name'] as String?)?.trim() ?? '';
      if (name.isEmpty) return null;

      final brand = (product['brands'] as String?)?.trim();
      final displayName =
          brand != null && brand.isNotEmpty && !name.contains(brand)
              ? '$name - $brand'
              : name;

      final categoriesRaw = product['categories'] as String?;
      final category = _extractFirstCategory(categoriesRaw) ?? 'Food';

      debugPrint('[OFF-Search] ✅ Found via search: $displayName');
      return BarcodeLookupResult(
        name: displayName,
        category: category,
        brand: brand,
      );
    } catch (e) {
      debugPrint('[OFF-Search] Error: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // Web Search Fallback (Scraper)
  // Scrapes DuckDuckGo HTML results directly to find the product
  // name from e-commerce sites. 100% free, no API keys.
  // ═══════════════════════════════════════════════════════════════

  Future<BarcodeLookupResult?> _lookupWebSearch(String barcode) async {
    try {
      final url = Uri.parse('https://html.duckduckgo.com/html/?q=$barcode+product');
      final response = await http.get(
        url,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return null;

      final html = response.body;

      // Extract titles using basic Regex
      final titleRegex = RegExp(r'<h2 class="result__title">.*?<a[^>]*>(.*?)</a>.*?</h2>', dotAll: true);
      final snippetRegex = RegExp(r'<a class="result__snippet[^>]*>(.*?)</a>', dotAll: true);

      final rawTitles = titleRegex
          .allMatches(html)
          .map((m) => m.group(1)?.replaceAll(RegExp(r'<[^>]*>'), '').trim())
          .where((t) => t != null && t.isNotEmpty)
          .cast<String>()
          .toList();

      final rawSnippets = snippetRegex
          .allMatches(html)
          .map((m) => m.group(1)?.replaceAll(RegExp(r'<[^>]*>'), '').trim())
          .where((s) => s != null)
          .cast<String>()
          .toList();

      if (rawTitles.isEmpty) return null;

      String? foundName;
      String? foundPrice;
      String? foundCategory;

      final priceRegex = RegExp(r'(?:EGP|جنيه|LE|L\.E|ج\.م|£|E£)\s*([0-9,]+(?:\.[0-9]{1,2})?)|([0-9,]+(?:\.[0-9]{1,2})?)\s*(?:EGP|جنيه|LE|L\.E|ج\.م|E£)', caseSensitive: false);

      for (var i = 0; i < rawTitles.length; i++) {
        var title = rawTitles[i];
        var snippet = rawSnippets.length > i ? rawSnippets[i] : '';

        // Extract Price
        if (foundPrice == null) {
          final titleMatch = priceRegex.firstMatch(title);
          final snippetMatch = priceRegex.firstMatch(snippet);
          if (titleMatch != null) {
            foundPrice = titleMatch.group(1) ?? titleMatch.group(2);
          } else if (snippetMatch != null) {
            foundPrice = snippetMatch.group(1) ?? snippetMatch.group(2);
          }
        }

        // Guess Category
        if (foundCategory == null) {
          final combined = ('$title $snippet').toLowerCase();
          if (combined.contains('eau de toilette') || combined.contains('perfume') || combined.contains('عطر') || combined.contains('برفان')) {
            foundCategory = 'Perfumes / عطور';
          } else if (combined.contains('shampoo') || combined.contains('شامبو') || combined.contains('hair')) {
            foundCategory = 'Hair Care / عناية بالشعر';
          } else if (combined.contains('skin') || combined.contains('بشرة') || combined.contains('cream') || combined.contains('كريم') || combined.contains('lotion')) {
            foundCategory = 'Skin Care / عناية بالبشرة';
          } else if (combined.contains('food') || combined.contains('طعام') || combined.contains('جبنة') || combined.contains('cheese') || combined.contains('snack') || combined.contains('chips')) {
            foundCategory = 'Food / مأكولات';
          } else if (combined.contains('beverage') || combined.contains('drink') || combined.contains('مشروب') || combined.contains('juice') || combined.contains('عصير')) {
             foundCategory = 'Beverages / مشروبات';
          }
        }

        // Extract Clean Name
        if (foundName == null && !title.toLowerCase().contains('barcode') && title.length > 5 && !RegExp(r'^[0-9]+$').hasMatch(title)) {
           String cleanTitle = title;
           final splitters = [' | ', ' - ', ' – '];
           for (final splitter in splitters) {
             if (cleanTitle.contains(splitter)) {
               final parts = cleanTitle.split(splitter);
               if (parts[0].length > 10) {
                 cleanTitle = parts[0];
               } else if (parts.length > 1 && parts[1].length > 15) {
                 cleanTitle = parts[1];
               }
             }
           }
           foundName = cleanTitle.trim();
        }
      }

      if (foundName != null && foundName.isNotEmpty) {
        debugPrint('[WebSearch] ✅ Found: $foundName (Price: $foundPrice, Cat: $foundCategory)');
        
        double? parsedPrice;
        if (foundPrice != null) {
           parsedPrice = double.tryParse(foundPrice.replaceAll(',', ''));
        }

        return BarcodeLookupResult(
          name: foundName,
          category: foundCategory,
          brand: null, // Hard to extract brand without LLM
          price: parsedPrice,
        );
      }

      return null;
    } catch (e) {
      debugPrint('[WebSearch] Error: $e');
      return null;
    }
  }

  // Removed Gemini methods as per user request

  // ═══════════════════════════════════════════════════════════════
  // Helpers
  // ═══════════════════════════════════════════════════════════════

  String? _extractFirstCategory(String? categoriesRaw) {
    if (categoriesRaw == null || categoriesRaw.isEmpty) return null;
    final cats = categoriesRaw
        .split(',')
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .toList();
    if (cats.isEmpty) return null;
    var cat = cats.first;
    if (cat.contains(':')) cat = cat.split(':').last.trim();
    if (cat.isEmpty) return null;
    return cat[0].toUpperCase() + cat.substring(1);
  }

  String? _cleanCategory(String? category) {
    if (category == null || category.isEmpty) return null;
    return category[0].toUpperCase() + category.substring(1);
  }
}
