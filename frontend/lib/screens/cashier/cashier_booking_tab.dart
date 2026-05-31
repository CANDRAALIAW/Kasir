import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/booking_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../models/cat_booking.dart';
import '../../models/product.dart';

class CashierBookingTab extends StatefulWidget {
  const CashierBookingTab({super.key});

  @override
  State<CashierBookingTab> createState() => _CashierBookingTabState();
}

class _CashierBookingTabState extends State<CashierBookingTab> {
  String _statusFilter = 'all';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Provider.of<AuthProvider>(context, listen: false).user;
      Provider.of<BookingProvider>(context, listen: false).fetchBookings(user?.branchId);
      Provider.of<ProductProvider>(context, listen: false).fetchProducts(user?.branchId);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddBookingDialog() {
    final products = Provider.of<ProductProvider>(context, listen: false)
        .products
        .where((p) => p.type == 'service')
        .toList();

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AddBookingDialog(products: products),
    ).then((success) {
      if (success == true) {
        final user = authProvider.user;
        bookingProvider.fetchBookings(user?.branchId);
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: const Text('Booking berhasil ditambahkan!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bookingProvider = Provider.of<BookingProvider>(context);

    // Filter bookings based on status and search query
    final filteredBookings = bookingProvider.bookings.where((b) {
      final matchesStatus = _statusFilter == 'all' || b.status == _statusFilter;
      final matchesSearch = b.ownerName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          b.catName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          b.catBreed.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesStatus && matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: Column(
            children: [
              _buildHeader(context),
              _buildFilters(),
              _buildSearchField(),
              Expanded(
                child: bookingProvider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filteredBookings.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                            itemCount: filteredBookings.length,
                            itemBuilder: (ctx, i) {
                              final booking = filteredBookings[i];
                              return _buildBookingCard(booking);
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddBookingDialog,
        backgroundColor: Colors.pink,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Booking Jasa', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Layanan Jasa Kucing',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF880E4F)),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          _buildFilterChip('all', 'Semua'),
          const SizedBox(width: 8),
          _buildFilterChip('pending', 'Antrean'),
          const SizedBox(width: 8),
          _buildFilterChip('ongoing', 'Diproses'),
          const SizedBox(width: 8),
          _buildFilterChip('completed', 'Selesai'),
          const SizedBox(width: 8),
          _buildFilterChip('cancelled', 'Batal'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _statusFilter == value;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.pink.shade700,
          fontWeight: FontWeight.bold,
        ),
      ),
      selected: isSelected,
      selectedColor: Colors.pink,
      backgroundColor: Colors.pink.shade50.withValues(alpha: 0.5),
      onSelected: (val) {
        if (val) {
          setState(() {
            _statusFilter = value;
          });
        }
      },
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.pink.shade100),
      ),
      showCheckmark: false,
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val),
        decoration: InputDecoration(
          hintText: 'Cari owner, kucing, ras...',
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
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today_outlined, size: 80, color: Colors.pink.shade100),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty ? 'Tidak ada data booking' : 'Tidak ada booking yang cocok',
            style: TextStyle(color: Colors.pink.shade300, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingCard(CatBooking booking) {
    final isGrooming = booking.bookingType == 'grooming';
    final DateFormat formatter = DateFormat('dd MMM yyyy, HH:mm');

    Color statusColor;
    String statusLabel;
    switch (booking.status) {
      case 'pending':
        statusColor = Colors.orange;
        statusLabel = 'Antre';
        break;
      case 'ongoing':
        statusColor = Colors.blue;
        statusLabel = 'Diproses';
        break;
      case 'completed':
        statusColor = Colors.green;
        statusLabel = 'Selesai';
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusLabel = 'Batal';
        break;
      default:
        statusColor = Colors.grey;
        statusLabel = booking.status;
    }

    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.pink.shade50),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isGrooming ? Colors.purple.shade50 : Colors.teal.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isGrooming ? Icons.wash_outlined : Icons.hotel_outlined,
                        color: isGrooming ? Colors.purple : Colors.teal,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isGrooming ? 'Grooming Kucing' : 'Pet Hotel Kucing',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            const Divider(height: 24, thickness: 0.5),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('Pemilik', '${booking.ownerName} (${booking.ownerPhone})'),
                      const SizedBox(height: 6),
                      _buildInfoRow('Kucing', '${booking.catName} - Ras ${booking.catBreed}'),
                      const SizedBox(height: 6),
                      _buildInfoRow('Paket', booking.product?.name ?? 'Loading...'),
                      const SizedBox(height: 6),
                      _buildInfoRow('Tanggal Masuk', formatter.format(booking.startDate)),
                      if (booking.endDate != null) ...[
                        const SizedBox(height: 6),
                        _buildInfoRow('Tanggal Keluar', formatter.format(booking.endDate!)),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Harga Layanan', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    Text(
                      'Rp ${_formatRp(booking.price)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.pink),
                    ),
                  ],
                )
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (booking.status == 'pending') ...[
                  TextButton.icon(
                    onPressed: () => _updateBookingStatus(booking.id, 'cancelled'),
                    icon: const Icon(Icons.cancel_outlined, color: Colors.red, size: 18),
                    label: const Text('Batalkan', style: TextStyle(color: Colors.red)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _updateBookingStatus(booking.id, 'ongoing'),
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('Mulai Proses'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      backgroundColor: Colors.blue,
                    ),
                  ),
                ] else if (booking.status == 'ongoing') ...[
                  ElevatedButton.icon(
                    onPressed: () => _updateBookingStatus(booking.id, 'completed'),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Selesaikan'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      backgroundColor: Colors.green,
                    ),
                  ),
                ] else if (booking.status == 'completed' && booking.transactionId == null) ...[
                  ElevatedButton.icon(
                    onPressed: () {
                      if (booking.product != null) {
                        cartProvider.addItem(booking.product!);
                        // Store the booking linkage in CartProvider
                        cartProvider.setLinkedBookingId(booking.id);

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Jasa ${booking.product!.name} masuk keranjang POS!'),
                            backgroundColor: Colors.pink,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            action: SnackBarAction(
                              label: 'Bayar',
                              textColor: Colors.white,
                              onPressed: () {
                                // Close dialog, or go to cart
                              },
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.shopping_cart_checkout, size: 18),
                    label: const Text('Bayar di POS'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      backgroundColor: Colors.pink,
                    ),
                  ),
                ] else if (booking.transactionId != null) ...[
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Lunas (Paid)',
                        style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ]
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            '$label:',
            style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
        ),
      ],
    );
  }

  void _updateBookingStatus(int id, String status) async {
    final provider = Provider.of<BookingProvider>(context, listen: false);
    final success = await provider.updateBooking(id, {'status': status});
    if (success && mounted) {
      final user = Provider.of<AuthProvider>(context, listen: false).user;
      provider.fetchBookings(user?.branchId);
    }
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

class AddBookingDialog extends StatefulWidget {
  final List<Product> products;
  const AddBookingDialog({super.key, required this.products});

  @override
  State<AddBookingDialog> createState() => _AddBookingDialogState();
}

class _AddBookingDialogState extends State<AddBookingDialog> {
  final _formKey = GlobalKey<FormState>();
  final _ownerNameController = TextEditingController();
  final _ownerPhoneController = TextEditingController();
  final _catNameController = TextEditingController();
  final _catBreedController = TextEditingController();

  String _bookingType = 'grooming'; // grooming, pethotel
  Product? _selectedProduct;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;

  @override
  void dispose() {
    _ownerNameController.dispose();
    _ownerPhoneController.dispose();
    _catNameController.dispose();
    _catBreedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Filter services based on type
    final filteredServices = widget.products.where((p) {
      if (_bookingType == 'grooming') {
        return p.name.toLowerCase().contains('grooming');
      } else {
        return p.name.toLowerCase().contains('hotel');
      }
    }).toList();

    // Auto select first product if selection is empty or invalid
    if (_selectedProduct == null || !filteredServices.contains(_selectedProduct)) {
      _selectedProduct = filteredServices.isNotEmpty ? filteredServices.first : null;
    }

    final user = Provider.of<AuthProvider>(context, listen: false).user;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Row(
        children: [
          Icon(Icons.pets, color: Colors.pink),
          SizedBox(width: 8),
          Text('Booking Jasa Kucing', style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            children: [
              TextFormField(
                controller: _ownerNameController,
                decoration: const InputDecoration(labelText: 'Nama Owner/Pemilik', prefixIcon: Icon(Icons.person)),
                validator: (val) => val == null || val.isEmpty ? 'Nama owner harus diisi' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ownerPhoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'No. HP Owner/Pemilik', prefixIcon: Icon(Icons.phone)),
                validator: (val) => val == null || val.isEmpty ? 'No HP harus diisi' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _catNameController,
                decoration: const InputDecoration(labelText: 'Nama Kucing', prefixIcon: Icon(Icons.pets)),
                validator: (val) => val == null || val.isEmpty ? 'Nama kucing harus diisi' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _catBreedController,
                decoration: const InputDecoration(
                  labelText: 'Ras Kucing (misal: Persi, Anggora)', 
                  prefixIcon: Icon(Icons.type_specimen_outlined)
                ),
                validator: (val) => val == null || val.isEmpty ? 'Ras kucing harus diisi' : null,
              ),
              const SizedBox(height: 16),
              const Text('Tipe Jasa', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('Grooming')),
                      selected: _bookingType == 'grooming',
                      onSelected: (val) {
                        if (val) setState(() => _bookingType = 'grooming');
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('Pet Hotel')),
                      selected: _bookingType == 'pethotel',
                      onSelected: (val) {
                        if (val) setState(() => _bookingType = 'pethotel');
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Pilih Paket Layanan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 6),
              if (filteredServices.isEmpty)
                const Text('Tidak ada paket layanan tersedia.', style: TextStyle(color: Colors.red, fontSize: 13))
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.pink.shade50.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<Product>(
                      value: _selectedProduct,
                      isExpanded: true,
                      onChanged: (Product? val) {
                        setState(() {
                          _selectedProduct = val;
                        });
                      },
                      items: filteredServices.map((Product p) {
                        return DropdownMenuItem<Product>(
                          value: p,
                          child: Text('${p.name} (Rp ${p.price.toInt()})'),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Tanggal Masuk', style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.bold)),
                subtitle: Text(DateFormat('dd MMM yyyy, HH:mm').format(_startDate)),
                trailing: const Icon(Icons.calendar_month, color: Colors.pink),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _startDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 1)),
                    lastDate: DateTime.now().add(const Duration(days: 30)),
                  );
                  if (date != null) {
                    if (!context.mounted) return;
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(_startDate),
                    );
                    if (time != null && mounted) {
                      setState(() {
                        _startDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                      });
                    }
                  }
                },
              ),
              if (_bookingType == 'pethotel') ...[
                const Divider(height: 20),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tanggal Keluar', style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.bold)),
                  subtitle: Text(_endDate == null
                      ? 'Pilih tanggal keluar'
                      : DateFormat('dd MMM yyyy, HH:mm').format(_endDate!)),
                  trailing: const Icon(Icons.calendar_month, color: Colors.pink),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _endDate ?? _startDate.add(const Duration(days: 1)),
                      firstDate: _startDate,
                      lastDate: _startDate.add(const Duration(days: 90)),
                    );
                    if (date != null) {
                      if (!context.mounted) return;
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(_endDate ?? _startDate.add(const Duration(days: 1))),
                      );
                      if (time != null && mounted) {
                        setState(() {
                          _endDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                        });
                      }
                    }
                  },
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _selectedProduct == null
              ? null
              : () async {
                  if (_formKey.currentState!.validate()) {
                    if (_bookingType == 'pethotel' && _endDate == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Harap pilih tanggal keluar untuk Pet Hotel')),
                      );
                      return;
                    }

                    final data = {
                      'owner_name': _ownerNameController.text,
                      'owner_phone': _ownerPhoneController.text,
                      'cat_name': _catNameController.text,
                      'cat_breed': _catBreedController.text,
                      'booking_type': _bookingType,
                      'product_id': _selectedProduct!.id,
                      'price': _selectedProduct!.price,
                      'start_date': _startDate.toIso8601String(),
                      'end_date': _endDate?.toIso8601String(),
                      'branch_id': user?.branchId ?? 1,
                    };

                    final provider = Provider.of<BookingProvider>(context, listen: false);
                    final success = await provider.addBooking(data);
                    if (success && context.mounted) {
                      Navigator.pop(context, true);
                    }
                  }
                },
          child: const Text('Simpan Booking'),
        ),
      ],
    );
  }
}
