import 'dart:async';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/food_product.dart';
import '../domain/portion.dart';

abstract interface class ProductLookupRepository {
  Future<FoodProduct?> findByBarcode(
    String barcode, {
    String languageCode = 'pt',
  });

  /// Products already looked up on this device, newest first. Served from
  /// the local cache only, so it works offline.
  Future<List<FoodProduct>> recentProducts({int limit = 6});
}

class OpenFoodFactsRepository implements ProductLookupRepository {
  OpenFoodFactsRepository(this.database, {Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://world.openfoodfacts.org/api/v2',
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 8),
              headers: const {
                'User-Agent': 'VYRO/0.1.0 (contact: hello@vyro.app)',
              },
            ),
          );

  final AppDatabase database;
  final Dio _dio;
  static DateTime? _lastRequestAt;
  static const _minimumRequestInterval = Duration(milliseconds: 4200);

  @override
  Future<FoodProduct?> findByBarcode(
    String barcode, {
    String languageCode = 'pt',
  }) async {
    final normalized = barcode.replaceAll(RegExp(r'\s+'), '');
    if (!_isSupportedGtin(normalized)) {
      throw const ProductLookupException.invalidBarcode();
    }

    final cached = await database.cachedProduct(normalized);
    if (cached != null) return _fromCache(cached);

    await _waitForRateLimit();
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/product/$normalized',
        queryParameters: {
          'fields':
              'code,product_name,product_name_en,brands,quantity,nutriments,'
              'nutriscore_grade,serving_size,serving_quantity,'
              'product_quantity,product_quantity_unit',
          'lc': languageCode,
        },
      );
      final body = response.data;
      if (body == null || body['status'] != 1 || body['product'] is! Map) {
        return null;
      }

      final data = Map<String, dynamic>.from(body['product'] as Map);
      final nutrientData = data['nutriments'] is Map
          ? Map<String, dynamic>.from(data['nutriments'] as Map)
          : const <String, dynamic>{};
      final name =
          _nonEmpty(data['product_name']) ?? _nonEmpty(data['product_name_en']);
      if (name == null) return null;

      final energyKj = _number(nutrientData['energy_100g']);
      final kcal =
          _number(nutrientData['energy-kcal_100g']) ??
          (energyKj == null ? null : energyKj / 4.184);
      final quantity = _nonEmpty(data['quantity']);
      final servingSize = _nonEmpty(data['serving_size']);
      final pack = parsePackQuantity(quantity);
      final quantityUnit = _nonEmpty(
        data['product_quantity_unit'],
      )?.toLowerCase();
      final product = FoodProduct(
        barcode: normalized,
        name: name,
        brand: _nonEmpty(data['brands']),
        quantity: quantity,
        servingSize: servingSize,
        servingGrams:
            _positive(data['serving_quantity']) ??
            parseServingGrams(servingSize),
        packageGrams: _positive(data['product_quantity']) ?? pack?.totalAmount,
        liquid: quantityUnit == 'ml' || (pack?.liquid ?? false),
        kcalPer100g: kcal,
        proteinPer100g: _number(nutrientData['proteins_100g']),
        carbsPer100g: _number(nutrientData['carbohydrates_100g']),
        fatPer100g: _number(nutrientData['fat_100g']),
        nutriScore: _nonEmpty(data['nutriscore_grade']),
      );
      await database.cacheProduct(_toCache(product));
      return product;
    } on DioException catch (error) {
      if (error.response?.statusCode == 429 ||
          error.response?.statusCode == 503) {
        throw const ProductLookupException.rateLimited();
      }
      if (error.response != null) {
        throw ProductLookupException.http(error.response!.statusCode);
      }
      throw const ProductLookupException.offline();
    }
  }

  @override
  Future<List<FoodProduct>> recentProducts({int limit = 6}) async =>
      (await database.recentCachedProducts(
        limit: limit,
      )).map(_fromCache).toList();

  Future<void> _waitForRateLimit() async {
    final last = _lastRequestAt;
    if (last != null) {
      final remaining =
          _minimumRequestInterval - DateTime.now().difference(last);
      if (remaining > Duration.zero) await Future<void>.delayed(remaining);
    }
    _lastRequestAt = DateTime.now();
  }

  FoodProduct _fromCache(CachedProduct product) => FoodProduct(
    barcode: product.barcode,
    name: product.name,
    brand: product.brand,
    quantity: product.quantity,
    kcalPer100g: product.kcalPer100g,
    proteinPer100g: product.proteinPer100g,
    carbsPer100g: product.carbsPer100g,
    fatPer100g: product.fatPer100g,
    nutriScore: product.nutriScore,
    servingSize: product.servingSize,
    servingGrams: product.servingGrams,
    packageGrams: product.packageGrams,
    liquid: product.liquid,
  );

  CachedProductsCompanion _toCache(FoodProduct product) =>
      CachedProductsCompanion.insert(
        barcode: product.barcode,
        name: product.name,
        brand: Value(product.brand),
        quantity: Value(product.quantity),
        kcalPer100g: Value(product.kcalPer100g),
        proteinPer100g: Value(product.proteinPer100g),
        carbsPer100g: Value(product.carbsPer100g),
        fatPer100g: Value(product.fatPer100g),
        nutriScore: Value(product.nutriScore),
        servingSize: Value(product.servingSize),
        servingGrams: Value(product.servingGrams),
        packageGrams: Value(product.packageGrams),
        liquid: Value(product.liquid),
        lastFetchedAt: DateTime.now(),
      );

  static double? _number(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.replaceAll(',', '.'));
    return null;
  }

  static double? _positive(Object? value) {
    final number = _number(value);
    return number != null && number > 0 && number.isFinite ? number : null;
  }

  static String? _nonEmpty(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static bool _isSupportedGtin(String code) {
    if (!RegExp(r'^\d+$').hasMatch(code) ||
        !const {8, 12, 13}.contains(code.length)) {
      return false;
    }
    var sum = 0;
    var weight = 3;
    for (var index = code.length - 2; index >= 0; index--) {
      sum += int.parse(code[index]) * weight;
      weight = weight == 3 ? 1 : 3;
    }
    final checkDigit = (10 - sum % 10) % 10;
    return checkDigit == int.parse(code[code.length - 1]);
  }
}

class ProductLookupException implements Exception {
  const ProductLookupException._(this.message, {this.statusCode});
  const ProductLookupException.invalidBarcode() : this._('invalid barcode');
  const ProductLookupException.offline() : this._('offline');
  const ProductLookupException.rateLimited() : this._('rate limited');
  const ProductLookupException.http(int? statusCode)
    : this._('service error', statusCode: statusCode);

  final String message;
  final int? statusCode;

  @override
  String toString() => 'ProductLookupException($message)';
}
