import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

class LocalStorageService {
  static const String _productsBox = 'products_cache';
  static const String _pendingTransactionsBox = 'pending_transactions';
  static const String _settingsBox = 'settings';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox<String>(_productsBox);
    await Hive.openBox<String>(_pendingTransactionsBox);
    await Hive.openBox<dynamic>(_settingsBox);
  }

  // Products Caching - keyed per branch
  static Future<void> cacheProducts(List<dynamic> products, {int? branchId}) async {
    final box = Hive.box<String>(_productsBox);
    final key = branchId != null ? 'products_branch_$branchId' : 'products_all';
    await box.put(key, jsonEncode(products));
  }

  static List<dynamic> getCachedProducts({int? branchId}) {
    final box = Hive.box<String>(_productsBox);
    final key = branchId != null ? 'products_branch_$branchId' : 'products_all';
    final data = box.get(key);
    if (data != null) {
      return jsonDecode(data);
    }
    return [];
  }

  // Pending Transactions (Offline Sync)
  static Future<void> queueTransaction(Map<String, dynamic> tx) async {
    final box = Hive.box<String>(_pendingTransactionsBox);
    final key = DateTime.now().millisecondsSinceEpoch.toString();
    await box.put(key, jsonEncode(tx));
  }

  static Map<String, String> getPendingTransactions() {
    final box = Hive.box<String>(_pendingTransactionsBox);
    return box.toMap().cast<String, String>();
  }

  static Future<void> removePendingTransaction(String key) async {
    final box = Hive.box<String>(_pendingTransactionsBox);
    await box.delete(key);
  }

  // Settings/Metadata
  static Future<void> save(String key, dynamic value) async {
    final box = Hive.box<dynamic>(_settingsBox);
    await box.put(key, value);
  }

  static dynamic get(String key) {
    final box = Hive.box<dynamic>(_settingsBox);
    return box.get(key);
  }
}
