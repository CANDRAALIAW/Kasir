import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import '../services/local_storage_service.dart';

class ProductProvider with ChangeNotifier {
  List<Product> _products = [];
  bool _isLoading = false;
  int? _lastFetchedBranchId;
  final ApiService _apiService = ApiService();

  List<Product> get products => _products;
  bool get isLoading => _isLoading;

  Future<void> fetchProducts(int? branchId) async {
    _isLoading = true;
    _lastFetchedBranchId = branchId;
    notifyListeners();

    try {
      final response = await _apiService.get('/products?branch_id=${branchId ?? ""}');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _products = data.map((json) => Product.fromJson(json)).toList();
        // Save to cache keyed by branch
        await LocalStorageService.cacheProducts(data, branchId: branchId);
      }
    } catch (e) {
      debugPrint('Fetch products error: $e. Using cache.');
      final cachedData = LocalStorageService.getCachedProducts(branchId: branchId);
      if (cachedData.isNotEmpty) {
        _products = cachedData.map((json) => Product.fromJson(json)).toList();
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> addProduct(Map<String, String> fields, String? imagePath) async {
    _isLoading = true;
    notifyListeners();

    try {
      final streamedResponse = await _apiService.postMultipart(
        '/products', 
        fields, 
        imagePath, 
        'image'
      );
      
      if (streamedResponse.statusCode == 201) {
        await fetchProducts(int.tryParse(fields['branch_id'] ?? ''));
        return true;
      }
    } catch (e) {
      debugPrint('Add product error: $e');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> updateProduct(int id, Map<String, String> fields, String? imagePath) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Laravel multipart PUT workaround: use POST with _method=PUT
      fields['_method'] = 'PUT';
      final streamedResponse = await _apiService.postMultipart(
        '/products/$id', 
        fields, 
        imagePath, 
        'image'
      );
      
      if (streamedResponse.statusCode == 200) {
        await fetchProducts(int.tryParse(fields['branch_id'] ?? ''));
        return true;
      }
    } catch (e) {
      debugPrint('Update product error: $e');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> deleteProduct(int id) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.delete('/products/$id');
      
      if (response.statusCode == 200) {
        _products.removeWhere((p) => p.id == id);
        // Update cache
        final cachedData = LocalStorageService.getCachedProducts(branchId: _lastFetchedBranchId);
        if (cachedData.isNotEmpty) {
          final updatedCache = cachedData.where((json) => json['id'] != id).toList();
          await LocalStorageService.cacheProducts(updatedCache, branchId: _lastFetchedBranchId);
        }
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Delete product error: $e');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }
}
