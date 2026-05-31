import 'product.dart';

class CatBooking {
  final int id;
  final String ownerName;
  final String ownerPhone;
  final String catName;
  final String catBreed;
  final String bookingType; // 'grooming' or 'pethotel'
  final int productId;
  final Product? product;
  final double price;
  final DateTime startDate;
  final DateTime? endDate;
  final String status; // 'pending', 'ongoing', 'completed', 'cancelled'
  final int branchId;
  final int? transactionId;
  final DateTime createdAt;

  CatBooking({
    required this.id,
    required this.ownerName,
    required this.ownerPhone,
    required this.catName,
    required this.catBreed,
    required this.bookingType,
    required this.productId,
    this.product,
    required this.price,
    required this.startDate,
    this.endDate,
    required this.status,
    required this.branchId,
    this.transactionId,
    required this.createdAt,
  });

  factory CatBooking.fromJson(Map<String, dynamic> json) {
    return CatBooking(
      id: json['id'],
      ownerName: json['owner_name'],
      ownerPhone: json['owner_phone'],
      catName: json['cat_name'],
      catBreed: json['cat_breed'],
      bookingType: json['booking_type'],
      productId: json['product_id'],
      product: json['product'] != null ? Product.fromJson(json['product']) : null,
      price: double.parse(json['price'].toString()),
      startDate: DateTime.parse(json['start_date']),
      endDate: json['end_date'] != null ? DateTime.parse(json['end_date']) : null,
      status: json['status'],
      branchId: json['branch_id'],
      transactionId: json['transaction_id'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
