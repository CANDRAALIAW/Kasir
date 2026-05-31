import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/product_provider.dart';
import '../../services/api_service.dart';
import '../../models/product.dart';

class RestockScreen extends StatefulWidget {
  final int? productId;
  const RestockScreen({super.key, this.productId});

  @override
  State<RestockScreen> createState() => _RestockScreenState();
}

class _RestockScreenState extends State<RestockScreen> {
  final ApiService _apiService = ApiService();
  int? _selectedProductId;
  final _qtyController = TextEditingController();
  final _noteController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedProductId = widget.productId;
  }

  Future<void> _handleRestock() async {
    if (_selectedProductId == null || _qtyController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harap pilih produk dan masukkan jumlah')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await _apiService.post('/inventory/restock', {
        'product_id': _selectedProductId,
        'quantity': int.parse(_qtyController.text),
        'note': _noteController.text,
      });

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Restock berhasil!')),
          );
          _qtyController.clear();
          _noteController.clear();
          setState(() => _selectedProductId = null);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final products = Provider.of<ProductProvider>(context).products;

    return Scaffold(
      backgroundColor: Colors.pink.shade50.withValues(alpha: 0.3),
      appBar: AppBar(
        title: const Text('Restock Inventaris'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: Colors.pink.shade100, width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.add_business_rounded, color: Colors.pink, size: 28),
                        SizedBox(width: 12),
                        Text(
                          'Isi Stok Produk',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF880E4F)),
                        ),
                      ],
                    ),
                    const Divider(height: 32, thickness: 1),
                    const Text('Pilih Produk', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF880E4F))),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      initialValue: products.any((p) => p.id == _selectedProductId) ? _selectedProductId : null,
                      items: products.map((Product p) => DropdownMenuItem<int>(
                        value: p.id,
                        child: Text(
                          p.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )).toList(),
                      onChanged: (val) => setState(() => _selectedProductId = val),
                      decoration: const InputDecoration(hintText: 'Pilih produk'),
                    ),
                    const SizedBox(height: 24),
                    const Text('Jumlah yang Ditambahkan', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF880E4F))),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _qtyController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: 'Masukkan jumlah'),
                    ),
                    const SizedBox(height: 24),
                    const Text('Catatan (Opsional)', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF880E4F))),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _noteController,
                      decoration: const InputDecoration(hintText: 'mis. Barang baru dari Supplier A'),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleRestock,
                        child: _isLoading 
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Perbarui Inventaris'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
