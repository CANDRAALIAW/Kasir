class Product {
  final int id;
  final String name;
  final String? description;
  final double price;
  final int stock;
  final int minimumStock;
  final String? imagePath;
  final int branchId;
  final String type; // 'product' or 'service'

  Product({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    required this.stock,
    this.minimumStock = 5,
    this.imagePath,
    required this.branchId,
    this.type = 'product',
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      name: json['nama'] ?? json['name'] ?? '',
      description: json['deskripsi'] ?? json['description'],
      price: double.tryParse((json['harga'] ?? json['price'] ?? 0.0).toString()) ?? 0.0,
      stock: json['stok'] ?? json['stock'] ?? 0,
      minimumStock: json['stok_minimum'] ?? json['minimum_stock'] ?? 5,
      imagePath: json['path_gambar'] ?? json['image_path'],
      branchId: json['id_cabang'] ?? json['branch_id'] ?? 0,
      type: json['jenis'] ?? json['type'] ?? 'product',
    );
  }
}

