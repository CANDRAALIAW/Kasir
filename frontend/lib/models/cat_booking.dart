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
    String status = json['status'] ?? 'pending';
    final statusMap = {
      'menunggu': 'pending',
      'berlangsung': 'ongoing',
      'selesai': 'completed',
      'dibatalkan': 'cancelled',
    };
    status = statusMap[status] ?? status;

    return CatBooking(
      id: json['id'],
      ownerName: json['nama_pemilik'] ?? json['owner_name'] ?? '',
      ownerPhone: json['telepon_pemilik'] ?? json['owner_phone'] ?? '',
      catName: json['nama_kucing'] ?? json['cat_name'] ?? '',
      catBreed: json['ras_kucing'] ?? json['cat_breed'] ?? '',
      bookingType: json['jenis_pemesanan'] ?? json['booking_type'] ?? '',
      productId: json['id_produk'] ?? json['product_id'] ?? 0,
      product: (json['produk'] != null)
          ? Product.fromJson(json['produk'])
          : (json['product'] != null ? Product.fromJson(json['product']) : null),
      price: double.tryParse((json['harga'] ?? json['price'] ?? 0.0).toString()) ?? 0.0,
      startDate: DateTime.parse(json['tanggal_mulai'] ?? json['start_date'] ?? DateTime.now().toIso8601String()),
      endDate: json['tanggal_selesai'] != null 
          ? DateTime.parse(json['tanggal_selesai']) 
          : (json['end_date'] != null ? DateTime.parse(json['end_date']) : null),
      status: status,
      branchId: json['id_cabang'] ?? json['branch_id'] ?? 0,
      transactionId: json['id_transaksi'] ?? json['transaction_id'],
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }
}
