import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';
import '../../providers/cart_provider.dart';
import '../../providers/auth_provider.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  String _selectedMethod = 'tunai'; // 'tunai', 'qris', 'transfer'
  final TextEditingController _cashPaidController = TextEditingController();
  double _paymentAmount = 0.0;
  double _changeAmount = 0.0;

  @override
  void dispose() {
    _cashPaidController.dispose();
    super.dispose();
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

  void _calculateChange(double totalAmount) {
    final val = double.tryParse(_cashPaidController.text) ?? 0.0;
    setState(() {
      _paymentAmount = val;
      if (val >= totalAmount) {
        _changeAmount = val - totalAmount;
      } else {
        _changeAmount = 0.0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final totalAmount = cart.totalAmount;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Keranjang Saya'),
        actions: [
          if (cart.items.isNotEmpty)
            IconButton(
              onPressed: () => _showClearConfirmation(context, cart),
              icon: const Icon(Icons.delete_sweep, color: Colors.red),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              Expanded(
                child: cart.items.isEmpty
                    ? _buildEmptyCart()
                    : ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          ...cart.items.values.map((item) => _buildCartItem(item, cart)),
                          const SizedBox(height: 16),
                          _buildPaymentMethodSelector(totalAmount),
                        ],
                      ),
              ),
              if (cart.items.isNotEmpty) _buildCheckoutCard(cart, auth, context),
            ],
          ),
        ),
      ),
    );
  }

  void _showClearConfirmation(BuildContext context, CartProvider cart) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kosongkan Keranjang?'),
        content: const Text('Ini akan menghapus semua item dari keranjang Anda.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          TextButton(
            onPressed: () {
              cart.clear();
              Navigator.pop(ctx);
            }, 
            child: const Text('Hapus Semua', style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.pink.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.shopping_basket_outlined, size: 80, color: Colors.pink.shade200),
          ),
          const SizedBox(height: 24),
          const Text('Keranjang Anda kosong', 
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          Text('Tambahkan produk untuk memulai', 
            style: TextStyle(color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _buildCartItem(CartItem item, CartProvider cart) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.pink.shade50),
        boxShadow: [
          BoxShadow(
            color: Colors.pink.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.pink.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: item.product.imagePath != null
                    ? Image.network(
                        '${ApiService.storageUrl}/${item.product.imagePath}',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Center(
                          child: Icon(Icons.pets, color: Colors.pink),
                        ),
                      )
                    : const Center(
                        child: Icon(Icons.pets, color: Colors.pink),
                      ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.product.name, 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('Rp ${_formatRp(item.product.price)}', 
                    style: TextStyle(color: Colors.pink.shade700, fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.pink.shade50.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _buildQtyBtn(Icons.remove, () => cart.decrementQuantity(item.product.id)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text('${item.quantity}', 
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                  _buildQtyBtn(Icons.add, () => cart.incrementQuantity(item.product.id)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQtyBtn(IconData icon, VoidCallback onPressed) {
    return SizedBox(
      width: 32,
      height: 32,
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 16, color: Colors.pink),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildPaymentMethodSelector(double totalAmount) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.pink.shade50.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.pink.shade50),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Metode Pembayaran', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF880E4F))),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildMethodButton('tunai', 'Tunai', Icons.payments_outlined)),
              const SizedBox(width: 8),
              Expanded(child: _buildMethodButton('qris', 'QRIS', Icons.qr_code_scanner_outlined)),
              const SizedBox(width: 8),
              Expanded(child: _buildMethodButton('transfer', 'Transfer', Icons.account_balance_outlined)),
            ],
          ),
          const SizedBox(height: 20),
          if (_selectedMethod == 'tunai') _buildCashPaymentSection(totalAmount),
          if (_selectedMethod == 'qris') _buildQrisPaymentSection(totalAmount),
          if (_selectedMethod == 'transfer') _buildTransferPaymentSection(),
        ],
      ),
    );
  }

  Widget _buildMethodButton(String method, String label, IconData icon) {
    final isSelected = _selectedMethod == method;
    return ElevatedButton.icon(
      onPressed: () {
        setState(() {
          _selectedMethod = method;
          if (method != 'tunai') {
            _cashPaidController.clear();
            _paymentAmount = 0.0;
            _changeAmount = 0.0;
          }
        });
      },
      icon: Icon(icon, size: 18, color: isSelected ? Colors.white : Colors.pink),
      label: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.pink, fontSize: 12, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Colors.pink : Colors.white,
        elevation: isSelected ? 2 : 0,
        side: BorderSide(color: Colors.pink.shade100),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildCashPaymentSection(double totalAmount) {
    // Generate quick nominal options
    final totalInt = totalAmount.toInt();
    final List<int> suggestions = [];
    suggestions.add(totalInt); // Uang pas

    final multiples = [20000, 50000, 100000];
    for (var mult in multiples) {
      if (mult > totalInt) {
        suggestions.add(mult);
      }
    }
    // Remove duplicates
    final uniqueSuggestions = suggestions.toSet().toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Uang Diterima', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        TextField(
          controller: _cashPaidController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: 'Masukkan nominal pembayaran...',
            prefixIcon: const Icon(Icons.payments, color: Colors.pink),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.pink.shade100)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.pink.shade100)),
          ),
          onChanged: (_) => _calculateChange(totalAmount),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: uniqueSuggestions.map((nom) => ActionChip(
            label: Text(
              nom == totalInt ? 'Uang Pas' : 'Rp ${_formatRp(nom)}',
              style: TextStyle(color: Colors.pink.shade900, fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.pink.shade50,
            onPressed: () {
              _cashPaidController.text = nom.toString();
              _calculateChange(totalAmount);
            },
          )).toList(),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.pink.shade50.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Kembalian', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.pink)),
              Text('Rp ${_formatRp(_changeAmount)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.pink)),
            ],
          ),
        ),
      ],
    );
  }

  // QRIS timer state - managed separately via StatefulBuilder
  Widget _buildQrisPaymentSection(double totalAmount) {
    return _QrisPaymentWidget(totalAmount: totalAmount);
  }

  Widget _buildTransferPaymentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Rekening Tujuan Transfer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        _buildBankTile('BCA', '0987654321', 'Earth Petshop'),
        const SizedBox(height: 8),
        _buildBankTile('Mandiri', '1234567890', 'Earth Petshop'),
      ],
    );
  }

  Widget _buildBankTile(String bank, String account, String name) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.pink.shade50),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$bank - $name', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              Text(account, style: TextStyle(color: Colors.pink.shade900, fontWeight: FontWeight.w600, fontSize: 14)),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 18, color: Colors.pink),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: account));
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Nomor rekening disalin!'),
                    duration: Duration(milliseconds: 1000),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutCard(CartProvider cart, AuthProvider auth, BuildContext context) {
    final double totalAmount = cart.totalAmount;
    final bool canCheckout = _selectedMethod != 'tunai' || _paymentAmount >= totalAmount;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(32), 
          topRight: Radius.circular(32)
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05), 
            blurRadius: 20, 
            offset: const Offset(0, -5)
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Pembayaran', 
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey)),
                Text('Rp ${_formatRp(totalAmount.toInt())}', 
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.pink)),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: cart.isProcessing || cart.items.isEmpty || !canCheckout
                    ? null 
                    : () async {
                        final method = _selectedMethod;
                        final double payAmt = method == 'tunai' ? _paymentAmount : totalAmount;
                        final double chgAmt = method == 'tunai' ? _changeAmount : 0.0;
                        final receiptText = _generateReceiptText(cart, method, payAmt, chgAmt);

                        final success = await cart.checkout(auth.user!.id, auth.user!.branchId!, method, payAmt, chgAmt);
                        if (success) {
                          if (!context.mounted) return;
                          _showSuccessOverlay(context, method, payAmt, chgAmt, receiptText);
                        }
                      },
                child: cart.isProcessing 
                    ? const SizedBox(
                        height: 20, 
                        width: 20, 
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      )
                    : Text(
                        !canCheckout ? 'Uang Bayar Kurang' : 'Selesaikan Transaksi', 
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _generateReceiptText(CartProvider cart, String method, double payAmt, double chgAmt) {
    final invoiceNum = 'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    final now = DateTime.now();
    final tanggal = '${now.day.toString().padLeft(2,'0')}/${now.month.toString().padLeft(2,'0')}/${now.year} '
        '${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}';
    final sb = StringBuffer();
    sb.writeln('🐾 *EARTH PETSHOP* 🐾');
    sb.writeln('━━━━━━━━━━━━━━━━━━━━━━━━');
    sb.writeln('🧾 Invoice : $invoiceNum');
    sb.writeln('📅 Tanggal : $tanggal');
    sb.writeln('💳 Metode  : ${method.toUpperCase()}');
    sb.writeln('━━━━━━━━━━━━━━━━━━━━━━━━');
    cart.items.forEach((key, item) {
      sb.writeln('▪ ${item.product.name}');
      sb.writeln('  ${item.quantity} x Rp ${_formatRp(item.product.price.toInt())} = *Rp ${_formatRp(item.subtotal.toInt())}*');
    });
    sb.writeln('━━━━━━━━━━━━━━━━━━━━━━━━');
    sb.writeln('💰 *TOTAL  : Rp ${_formatRp(cart.totalAmount.toInt())}*');
    sb.writeln('💵 Bayar   : Rp ${_formatRp(payAmt.toInt())}');
    if (chgAmt > 0) sb.writeln('🔄 Kembali : Rp ${_formatRp(chgAmt.toInt())}');
    sb.writeln('━━━━━━━━━━━━━━━━━━━━━━━━');
    sb.writeln('✨ Terima kasih telah berbelanja!');
    sb.writeln('🐱 Kami merawat hewan kesayangan Anda');
    return sb.toString();
  }

  void _shareReceiptWhatsApp(String receiptText) async {
    // Tampilkan dialog pilihan: kirim ke nomor pelanggan atau share umum
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) {
        final phoneCtrl = TextEditingController();
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.send_rounded, color: Colors.green, size: 28),
              SizedBox(width: 10),
              Text('Kirim via WhatsApp', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Masukkan nomor WA pelanggan (opsional):',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: 'cth: 0812xxxx atau 6281...',
                  prefixText: '+62 ',
                  prefixIcon: const Icon(Icons.phone, color: Colors.green),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                // Share tanpa nomor → buka WA picker
                _launchWhatsApp(null, receiptText);
              },
              child: const Text('Kirim Bebas', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.send, size: 16),
              label: const Text('Kirim'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                // Bersihkan nomor: hapus +62 / 0 di awal → ganti dengan 62
                String phone = phoneCtrl.text.trim().replaceAll(RegExp(r'\D'), '');
                if (phone.startsWith('0')) {
                  phone = '62${phone.substring(1)}';
                } else if (phone.startsWith('8')) {
                  phone = '62$phone';
                }
                _launchWhatsApp(phone.isEmpty ? null : phone, receiptText);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _launchWhatsApp(String? phone, String receiptText) async {
    final encoded = Uri.encodeComponent(receiptText);
    // Jika ada nomor, kirim langsung ke nomor itu
    // Jika tidak, buka share picker
    final uri = phone != null
        ? Uri.parse('https://wa.me/$phone?text=$encoded')
        : Uri.parse('https://api.whatsapp.com/send?text=$encoded');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('WhatsApp tidak ditemukan di perangkat ini')),
      );
    }
  }

  void _showSuccessOverlay(BuildContext context, String method, double payAmt, double chgAmt, String receiptText) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 40,
                backgroundColor: Colors.green,
                child: Icon(Icons.check, color: Colors.white, size: 50),
              ),
              const SizedBox(height: 24),
              const Text('Berhasil!', 
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Transaksi telah selesai.', 
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Mencetak struk... [Metode: ${method.toUpperCase()}, Bayar: Rp ${_formatRp(payAmt)}, Kembali: Rp ${_formatRp(chgAmt)}]'
                        )
                      ),
                    );
                  },
                  icon: const Icon(Icons.print),
                  label: const Text('Cetak Struk (Thermal)'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _shareReceiptWhatsApp(receiptText),
                  icon: const Icon(Icons.share, color: Colors.green),
                  label: const Text('Kirim Struk via WA', style: TextStyle(color: Colors.green)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: Colors.green),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx); // Close dialog
                    Navigator.pop(context); // Back to dashboard
                  },
                  child: const Text('Kembali ke Beranda'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QrisPaymentWidget extends StatefulWidget {
  final double totalAmount;
  const _QrisPaymentWidget({required this.totalAmount});

  @override
  State<_QrisPaymentWidget> createState() => _QrisPaymentWidgetState();
}

class _QrisPaymentWidgetState extends State<_QrisPaymentWidget> {
  static const int _countdownSeconds = 895; // ~14:55
  int _remaining = _countdownSeconds;
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (_remaining > 0) {
          _remaining--;
        } else {
          t.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String get _countdownText {
    final m = (_remaining ~/ 60).toString().padLeft(2, '0');
    final s = (_remaining % 60).toString().padLeft(2, '0');
    return '$m:$s';
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

  @override
  Widget build(BuildContext context) {
    final isExpired = _remaining == 0;
    return Center(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: isExpired ? Colors.red.shade100 : Colors.pink.shade100),
            ),
            child: Column(
              children: [
                const Text(
                  'QRIS DINAMIS EARTH PETSHOP',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF880E4F)),
                ),
                const SizedBox(height: 8),
                Opacity(
                  opacity: isExpired ? 0.3 : 1.0,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.pink.shade50),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Image.network(
                          'https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=qris_earthpetshop_${widget.totalAmount.toInt()}',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.qr_code, size: 80, color: Colors.black87),
                        ),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.pets, color: Colors.pink, size: 16),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'TOTAL: Rp ${_formatRp(widget.totalAmount)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.pink),
                ),
                const SizedBox(height: 4),
                if (isExpired)
                  const Text(
                    'QR Code Kadaluarsa',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.timer_outlined, size: 14,
                          color: _remaining < 60 ? Colors.red : Colors.orange),
                      const SizedBox(width: 4),
                      Text(
                        'Expired dalam $_countdownText',
                        style: TextStyle(
                          color: _remaining < 60 ? Colors.red : Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
