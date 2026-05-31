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
      name: json['name'],
      description: json['description'],
      price: double.parse(json['price'].toString()),
      stock: json['stock'],
      minimumStock: json['minimum_stock'] ?? 5,
      imagePath: json['image_path'],
      branchId: json['branch_id'],
      type: json['type'] ?? 'product',
    );
  }
}

