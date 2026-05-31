import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/cart_provider.dart';
import '../../services/local_storage_service.dart';
import 'product_management_tab.dart';
import 'user_management_tab.dart';
import 'admin_analytics_tab.dart';
import 'restock_screen.dart';
import 'activity_log_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;

  final List<Widget> _tabs = [
    const ProductManagementTab(),
    const UserManagementTab(),
    const AdminAnalyticsTab(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ProductProvider>(context, listen: false).fetchProducts(null);
    });
  }


  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).user;
    final pendingCount = LocalStorageService.getPendingTransactions().length;

    Widget offlineSyncBar = pendingCount > 0 ? Container(
      color: Colors.amber.shade700,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.cloud_off, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Mode Offline: Ada $pendingCount transaksi tertunda',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () async {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (ctx) => const Center(child: CircularProgressIndicator()),
                  );
                  
                  await Provider.of<CartProvider>(context, listen: false).syncOfflineTransactions();
                  
                  if (context.mounted) {
                    Navigator.pop(context); // Close spinner
                    setState(() {}); // Refresh
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Sinkronisasi transaksi selesai!'),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Sinkronkan',
                    style: TextStyle(color: Colors.amber.shade900, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ) : const SizedBox.shrink();

    return Scaffold(
      backgroundColor: Colors.pink.shade50,
      body: SafeArea(
        child: Column(
          children: [
            offlineSyncBar,
            _buildHeader(user?.name ?? 'Admin'),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: _tabs[_selectedIndex],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: NavigationBar(
          elevation: 0,
          backgroundColor: Colors.white,
          indicatorColor: Colors.pink.shade100,
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2, color: Colors.pink),
              label: 'Inventaris',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outlined),
              selectedIcon: Icon(Icons.people, color: Colors.pink),
              label: 'Kasir',
            ),
            NavigationDestination(
              icon: Icon(Icons.analytics_outlined),
              selectedIcon: Icon(Icons.analytics, color: Colors.pink),
              label: 'Analitik',
            ),
          ],
        ),
      ),
    );
  }

  void _showLowStockAlert(List<dynamic> lowStockProducts) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Peringatan Stok Menipis',
                style: const TextStyle(fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: lowStockProducts.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text('Semua produk memiliki stok yang cukup.', textAlign: TextAlign.center),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: lowStockProducts.length,
                    itemBuilder: (context, index) {
                      final p = lowStockProducts[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.inventory_2_outlined, color: Colors.orange.shade700),
                        title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Batas minimum: ${p.minimumStock}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: p.stock == 0 ? Colors.red.shade100 : Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Stok: ${p.stock}',
                                style: TextStyle(
                                  color: p.stock == 0 ? Colors.red.shade800 : Colors.orange.shade800,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.add_business_outlined, color: Colors.pink, size: 20),
                              tooltip: 'Isi Stok',
                              onPressed: () {
                                Navigator.pop(ctx);
                                final productProvider = Provider.of<ProductProvider>(context, listen: false);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => RestockScreen(productId: p.id)),
                                ).then((_) {
                                  productProvider.fetchProducts(null);
                                });
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
          if (lowStockProducts.isNotEmpty)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                final productProvider = Provider.of<ProductProvider>(context, listen: false);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RestockScreen()),
                ).then((_) {
                  productProvider.fetchProducts(null);
                });
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.pink),
              child: const Text('Isi Stok', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(String name) {
    final productProvider = Provider.of<ProductProvider>(context);
    final lowStockProducts = productProvider.products.where((p) => p.stock <= p.minimumStock).toList();
    final lowStockCount = lowStockProducts.length;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selamat datang kembali,',
                  style: TextStyle(color: Colors.pink.shade700, fontSize: 14),
                ),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF880E4F),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.notifications_outlined, 
                      color: lowStockCount > 0 ? Colors.orange : Colors.pink,
                    ),
                    onPressed: () => _showLowStockAlert(lowStockProducts),
                  ),
                  if (lowStockCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 14,
                          minHeight: 14,
                        ),
                        child: Text(
                          '$lowStockCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.pink),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                onSelected: (value) {
                  if (value == 'restock') {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const RestockScreen()));
                  } else if (value == 'security') {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ActivityLogScreen()));
                  } else if (value == 'logout') {
                    Provider.of<AuthProvider>(context, listen: false).logout();
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'restock',
                    child: Row(
                      children: [
                        Icon(Icons.add_business, color: Colors.pink, size: 20),
                        SizedBox(width: 12),
                        Text('Pengisian Stok'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'security',
                    child: Row(
                      children: [
                        Icon(Icons.security, color: Colors.pink, size: 20),
                        SizedBox(width: 12),
                        Text('Log Keamanan'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout, color: Colors.red, size: 20),
                        SizedBox(width: 12),
                        Text('Keluar', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ),
  ),
);
  }
}
