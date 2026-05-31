import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/cat_booking.dart';
import '../services/api_service.dart';

class BookingProvider with ChangeNotifier {
  List<CatBooking> _bookings = [];
  bool _isLoading = false;
  final ApiService _apiService = ApiService();

  List<CatBooking> get bookings => _bookings;
  bool get isLoading => _isLoading;

  Future<void> fetchBookings(int? branchId, {String status = 'all'}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.get('/bookings?branch_id=${branchId ?? ""}&status=$status');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _bookings = data.map((json) => CatBooking.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint('Fetch bookings error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> addBooking(Map<String, dynamic> bookingData) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.post('/bookings', bookingData);
      if (response.statusCode == 201) {
        final newBooking = CatBooking.fromJson(jsonDecode(response.body));
        _bookings.insert(0, newBooking);
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Add booking error: $e');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> updateBooking(int id, Map<String, dynamic> data) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.post('/bookings/$id', {
        ...data,
        '_method': 'PUT',
      });
      if (response.statusCode == 200) {
        final updatedBooking = CatBooking.fromJson(jsonDecode(response.body));
        final index = _bookings.indexWhere((b) => b.id == id);
        if (index != -1) {
          _bookings[index] = updatedBooking;
        }
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Update booking error: $e');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> deleteBooking(int id) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Create a DELETE request via manual HTTP request since apiService doesn't have a delete helper.
      // Wait, let's see if apiService has delete helper. No, it doesn't, but we can write one or call manual request or just delete via post using _method = DELETE.
      // Yes, Laravel supports POST with _method=DELETE.
      final response = await _apiService.post('/bookings/$id', {'_method': 'DELETE'});
      if (response.statusCode == 200) {
        _bookings.removeWhere((b) => b.id == id);
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Delete booking error: $e');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }
}
