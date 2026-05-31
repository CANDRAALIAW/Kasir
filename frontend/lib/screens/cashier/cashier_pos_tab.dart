import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import '../../providers/product_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../services/printer_service.dart';
import '../../services/api_service.dart';
import '../../models/product.dart';
import 'cart_screen.dart';

class CashierPosTab extends StatefulWidget {
  const CashierPosTab({super.key});

  @override
  State<CashierPosTab> createState() => _CashierPosTabState();
}

class _CashierPosTabState extends State<CashierPosTab> {
  final PrinterService _printerService = PrinterService();
  BluetoothDevice? _connectedDevice;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  void _showPrinterSettings() async {
    final devices = await _printerService.getDevices();
    if (mounted) {
      showModalBottomSheet(
        context: context,
        builder: (ctx) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Hubungkan Printer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              if (devices.isEmpty) const Text('Tidak ada perangkat yang dipasangkan.'),
              ...devices.map((d) => ListTile(
                title: Text(d.name ?? 'Tidak Diketahui'),
                subtitle: Text(d.address ?? ''),
                onTap: () async {
                  final success = await _printerService.connect(d);
                  if (success) {
                    if (ctx.mounted) {
                      setState(() => _connectedDevice = d);
                      Navigator.pop(ctx);
                    }
                  }
                },
              )),
            ],
          ),
        ),
      );
    }
  }

  void _showBarcodeScannerDialog() {
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    
    // Only physical products (type != 'service')
    final barcodeProducts = productProvider.products.where((p) => p.type != 'service').toList();

    showDialog(
      context: context,
      builder: (ctx) {
        String mockScanCode = '';
        final scanController = TextEditingController();
        
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Row(
                children: [
                  Icon(Icons.qr_code_scanner, color: Colors.pink),
                  SizedBox(width: 8),
                  Text('Pemindai Barcode', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Camera simulation box
                  Container(
                    width: double.infinity,
                    height: 160,
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Viewfinder lines
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white54, width: 2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        // Laser simulation
                        Positioned(
                          top: 80,
                          child: Container(
                            width: 110,
                            height: 2,
                            color: Colors.red,
                          ),
                        ),
                        const Positioned(
                          bottom: 12,
                          child: Text(
                            'Arahkan Barcode ke Kamera',
                            style: TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: scanController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Kode / Nama Produk',
                      hintText: 'Ketik kode barcode atau nama...',
                      prefixIcon: Icon(Icons.keyboard),
                    ),
                    onChanged: (val) {
                      setState(() {
                        mockScanCode = val;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Simulasi Cepat (Klik produk untuk scan):',
                    style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 80,
                    width: double.maxFinite,
                    child: barcodeProducts.isEmpty
                        ? const Center(child: Text('Tidak ada produk fisik'))
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: barcodeProducts.length,
                            itemBuilder: (context, index) {
                              final p = barcodeProducts[index];
                              return Card(
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.pink.shade50),
                                ),
                                child: InkWell(
                                  onTap: () {
                                    cartProvider.addItem(p);
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('[BARCODE SCAN] ${p.name} ditambahkan!'),
                                        backgroundColor: Colors.pink,
                                        duration: const Duration(seconds: 1),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    alignment: Alignment.center,
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p.name,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          'Rp ${p.price.toInt()}',
                                          style: const TextStyle(color: Colors.pink, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: mockScanCode.isEmpty
                      ? null
                      : () {
                          try {
                            final match = barcodeProducts.firstWhere(
                              (p) => p.name.toLowerCase().contains(mockScanCode.toLowerCase()),
                            );
                            cartProvider.addItem(match);
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('[BARCODE SCAN] ${match.name} ditambahkan!'),
                                backgroundColor: Colors.pink,
                                duration: const Duration(seconds: 1),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          } catch (_) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Produk tidak ditemukan!')),
                            );
                          }
                        },
                  child: const Text('Scan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Provider.of<AuthProvider>(context, listen: false).user;
      Provider.of<ProductProvider>(context, listen: false).fetchProducts(user?.branchId);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = Provider.of<ProductProvider>(context);
    final cartProvider = Provider.of<CartProvider>(context);
    
    final products = productProvider.products.where((p) {
      return p.type != 'service' && p.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    final width = MediaQuery.of(context).size.width;
    int crossAxisCount = 2;
    if (width > 1200) {
      crossAxisCount = 5;
    } else if (width > 900) {
      crossAxisCount = 4;
    } else if (width > 600) {
      crossAxisCount = 3;
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              _buildHeader(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Cari produk...',
                    prefixIcon: const Icon(Icons.search, color: Colors.pink),
                    suffixIcon: _searchQuery.isNotEmpty 
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  ),
                ),
              ),
              Expanded(
                child: productProvider.isLoading
                    ? _buildShimmerLoading(crossAxisCount)
                    : products.isEmpty 
                        ? _buildEmptyState()
                        : GridView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              childAspectRatio: 0.75,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                            ),
                            itemCount: products.length,
                            itemBuilder: (ctx, i) {
                              final product = products[i];
                              return _buildProductCard(product, cartProvider);
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: cartProvider.itemCount > 0
          ? FloatingActionButton.extended(
              backgroundColor: Theme.of(context).primaryColor,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (ctx) => const CartScreen()),
                );
              },
              label: Text(
                'Keranjang (${cartProvider.itemCount})', 
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
              ),
              icon: const Icon(Icons.shopping_cart, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Produk', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Row(
            children: [
              IconButton.filledTonal(
                onPressed: _showBarcodeScannerDialog,
                icon: const Icon(Icons.qr_code_scanner, color: Colors.pink),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: _showPrinterSettings,
                icon: Icon(
                  _connectedDevice == null ? Icons.print_disabled : Icons.print,
                  color: _connectedDevice == null ? Colors.grey : Colors.pink,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading(int crossAxisCount) {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: 6,
      itemBuilder: (ctx, i) => Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 80, color: Colors.pink.shade100),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty ? 'Tidak ada produk tersedia' : 'Tidak ada produk yang cocok dengan "$_searchQuery"',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.pink.shade300, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Product product, CartProvider cart) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.pink.shade50),
      ),
      child: InkWell(
        onTap: product.stock > 0 ? () => _addToCart(product, cart) : null,
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Container(
                    margin: const EdgeInsets.all(8),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.pink.shade50.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: product.imagePath != null
                          ? Image.network(
                              '${ApiService.storageUrl}/${product.imagePath}',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => const Center(
                                child: Icon(Icons.pets, size: 40, color: Colors.pink),
                              ),
                            )
                          : const Center(
                              child: Icon(Icons.pets, size: 40, color: Colors.pink),
                            ),
                    ),
                  ),
                  if (product.stock <= product.minimumStock && product.stock > 0)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Stok: ${product.stock}',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  if (product.stock == 0)
                    Container(
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Center(
                        child: Text(
                          'STOK HABIS',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Rp ${_formatRp(product.price)}',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold, 
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addToCart(dynamic product, CartProvider cart) {
    cart.addItem(product);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text('${product.name} ditambahkan ke keranjang')),
          ],
        ),
        duration: const Duration(milliseconds: 1500),
        backgroundColor: Colors.pink,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  String _formatRp(dynamic price) {
    final number = (price is num ? price : num.tryParse(price.toString()) ?? 0).toInt();
    final str = number.toString();
    final result = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) result.write('.');
      result.write(str[i]);
    }
    return result.toString();
  }
}
