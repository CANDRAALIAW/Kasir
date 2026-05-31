import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import '../services/local_storage_service.dart';

class CartItem {
  final Product product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});

  double get subtotal => product.price * quantity;
}

class CartProvider with ChangeNotifier {
  final Map<int, CartItem> _items = {};
  final ApiService _apiService = ApiService();
  bool _isProcessing = false;
  bool _isOffline = false;
  int? _linkedBookingId;

  Map<int, CartItem> get items => {..._items};
  bool get isProcessing => _isProcessing;
  bool get isOffline => _isOffline;
  int? get linkedBookingId => _linkedBookingId;

  void setLinkedBookingId(int? id) {
    _linkedBookingId = id;
    notifyListeners();
  }

  int get itemCount => _items.length;

  double get totalAmount {
    double total = 0.0;
    _items.forEach((key, cartItem) {
      total += cartItem.subtotal;
    });
    return total;
  }

  void addItem(Product product) {
    if (_items.containsKey(product.id)) {
      _items.update(
        product.id,
        (existing) => CartItem(
          product: existing.product,
          quantity: existing.quantity + 1,
        ),
      );
    } else {
      _items.putIfAbsent(
        product.id,
        () => CartItem(product: product),
      );
    }
    notifyListeners();
  }

  void incrementQuantity(int productId) {
    if (_items.containsKey(productId)) {
      _items.update(
        productId,
        (existing) => CartItem(
          product: existing.product,
          quantity: existing.quantity + 1,
        ),
      );
      notifyListeners();
    }
  }

  void decrementQuantity(int productId) {
    if (_items.containsKey(productId)) {
      if (_items[productId]!.quantity > 1) {
        _items.update(
          productId,
          (existing) => CartItem(
            product: existing.product,
            quantity: existing.quantity - 1,
          ),
        );
      } else {
        _items.remove(productId);
      }
      notifyListeners();
    }
  }

  void removeItem(int productId) {
    _items.remove(productId);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }

  Future<bool> checkout(int userId, int branchId, String paymentMethod, double paymentAmount, double changeAmount) async {
    if (_items.isEmpty) return false;

    _isProcessing = true;
    notifyListeners();

    final body = {
      'user_id': userId,
      'branch_id': branchId,
      'total': totalAmount,
      'payment_method': paymentMethod,
      'payment_amount': paymentAmount,
      'change_amount': changeAmount,
      if (_linkedBookingId != null) 'booking_id': _linkedBookingId,
      'items': _items.values.map((item) => {
        'product_id': item.product.id,
        'qty': item.quantity,
      }).toList(),
    };

    try {
      final response = await _apiService.post('/transactions', body);
      if (response.statusCode == 201) {
        clear();
        _linkedBookingId = null;
        _isProcessing = false;
        _isOffline = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Checkout error: $e. Queueing for offline sync.');
      await LocalStorageService.queueTransaction(body);
      clear();
      _linkedBookingId = null;
      _isProcessing = false;
      _isOffline = true;
      notifyListeners();
      return true; // Return true because it's "handled"
    }

    _isProcessing = false;
    notifyListeners();
    return false;
  }

  Future<void> syncOfflineTransactions() async {
    final pending = LocalStorageService.getPendingTransactions();
    if (pending.isEmpty) return;

    debugPrint('Syncing ${pending.length} offline transactions...');
    for (var entry in pending.entries) {
      try {
        final body = jsonDecode(entry.value);
        final response = await _apiService.post('/transactions', body);
        if (response.statusCode == 201) {
          await LocalStorageService.removePendingTransaction(entry.key);
        }
      } catch (e) {
        debugPrint('Sync error for key ${entry.key}: $e');
        break; // Stop syncing if still offline
      }
    }
    notifyListeners();
  }
}
