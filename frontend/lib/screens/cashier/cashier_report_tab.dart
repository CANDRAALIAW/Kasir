import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';

class CashierReportTab extends StatefulWidget {
  const CashierReportTab({super.key});

  @override
  State<CashierReportTab> createState() => _CashierReportTabState();
}

class _CashierReportTabState extends State<CashierReportTab> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _reportData;
  List<dynamic> _chartData = [];
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();
  bool _filterByDate = false; // By default show all history

  String _searchQuery = '';
  String _selectedPaymentMethod = 'semua';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchDailyReport(),
      _fetchIncomeStats(),
    ]);
    setState(() => _isLoading = false);
  }

  Future<void> _fetchDailyReport() async {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    try {
      String endpoint = '/transactions?branch_id=${user?.branchId ?? ""}';
      if (_filterByDate) {
        endpoint += '&date_start=$dateStr&date_end=$dateStr';
      }
      if (_searchQuery.isNotEmpty) {
        endpoint += '&search=${Uri.encodeComponent(_searchQuery)}';
      }
      if (_selectedPaymentMethod != 'semua') {
        endpoint += '&payment_method=$_selectedPaymentMethod';
      }

      final response = await _apiService.get(endpoint);
      final body = jsonDecode(response.body);
      final List<dynamic> list = (body is Map && body.containsKey('data'))
          ? (body['data'] as List? ?? [])
          : (body is List ? body : []);

      // Compute aggregates locally for statistics cards
      double totalIncome = 0;
      for (var tx in list) {
        totalIncome += double.tryParse(tx['total'].toString()) ?? 0.0;
      }

      setState(() {
        _reportData = {
          'transactions': list,
          'total_income': totalIncome,
          'transaction_count': list.length,
        };
      });
    } catch (e) {
      debugPrint('Fetch report error: $e');
    }
  }

  Future<void> _fetchIncomeStats() async {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    try {
      // Ambil data 7 hari terakhir: fetch per-hari lalu gabungkan
      final now = DateTime.now();
      final futures = List.generate(7, (i) {
        final day = now.subtract(Duration(days: 6 - i));
        final dateStr = DateFormat('yyyy-MM-dd').format(day);
        return _apiService
            .get('/reports/income?branch_id=${user?.branchId ?? ""}&type=daily&date=$dateStr')
            .then((r) {
          final body = jsonDecode(r.body);
          final dayData = body['data'] as List? ?? [];
          double total = dayData.fold(0.0, (sum, d) => sum + (double.tryParse(d['value'].toString()) ?? 0.0));
          return {'date': day, 'total': total};
        });
      });
      final results = await Future.wait(futures);
      if (mounted) {
        setState(() {
          _chartData = results;
        });
      }
    } catch (e) {
      debugPrint('Fetch stats error: $e');
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
              onSurface: Colors.pink.shade900,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _filterByDate = true;
      });
      _refreshAll();
    }
  }

  Future<void> _exportExcel() async {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Mengunduh laporan...'),
          ],
        ),
        duration: Duration(seconds: 30),
        backgroundColor: Colors.pink,
      ),
    );

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      String urlStr = '${ApiService.baseUrl}/reports/export?branch_id=${user?.branchId ?? ""}';
      if (_filterByDate) urlStr += '&start_date=$dateStr&end_date=$dateStr';

      final response = await http.get(
        Uri.parse(urlStr),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (response.statusCode == 200) {
        final dir = await getApplicationDocumentsDirectory();
        final fileName = 'Laporan_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Laporan disimpan: $fileName'),
              backgroundColor: Colors.green,
              action: SnackBarAction(
                label: 'Buka',
                textColor: Colors.white,
                onPressed: () async {
                  final uri = Uri.file(file.path);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal mengunduh: ${response.statusCode}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error ekspor: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 20),
                  _buildStatsCard(),
                  const SizedBox(height: 24),
                  const Text('Tren Pendapatan (7 Hari Terakhir)', 
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 16),
                  _buildChart(),
                  const SizedBox(height: 32),
                  _buildRecentTransactionsHeader(),
                  const SizedBox(height: 12),
                  _buildFiltersRow(),
                  const SizedBox(height: 16),
                  _buildTransactionsList(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Riwayat Transaksi',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF880E4F)),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _filterByDate
                          ? DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(_selectedDate)
                          : 'Semua Riwayat Transaksi',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_filterByDate) ...[
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _filterByDate = false;
                        });
                        _refreshAll();
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Tampilkan Semua', style: TextStyle(fontSize: 12, color: Colors.pink, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          icon: const Icon(Icons.calendar_today),
          onPressed: _selectDate,
          color: Theme.of(context).primaryColor,
        ),
      ],
    );
  }

  Widget _buildStatsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.pink.shade400, Colors.pink.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.pink.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildStatItem('Pesanan', _reportData?['transaction_count'].toString() ?? '0', Icons.shopping_bag),
          Container(width: 1, height: 40, color: Colors.white24),
          _buildStatItem('Pendapatan', 'Rp ${_formatRp(_reportData?['total_income'])}', Icons.payments),
        ],
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

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(height: 8),
          Text(value, 
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          Text(label, 
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  String _abbreviateRp(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1).replaceAll('.0', '')}jt';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}rb';
    return value.toStringAsFixed(0);
  }

  Widget _buildChart() {
    if (_chartData.isEmpty) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart_outlined, size: 40, color: Colors.pink.shade100),
            const SizedBox(height: 8),
            const Text('Tidak ada data transaksi', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    final spots = _chartData.asMap().entries.map((e) {
      final total = double.tryParse(e.value['total'].toString()) ?? 0.0;
      return FlSpot(e.key.toDouble(), total);
    }).toList();

    double maxY = spots.fold(0.0, (m, s) => s.y > m ? s.y : m);
    if (maxY == 0) maxY = 10000;
    maxY *= 1.2;

    return Container(
      height: 220,
      padding: const EdgeInsets.only(right: 12, top: 8, bottom: 4),
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: 6,
          minY: 0,
          maxY: maxY,
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => Colors.pink.shade800,
              getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
                'Rp ${_formatRp(s.y.toInt())}',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              )).toList(),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (v) => FlLine(
              color: Colors.pink.shade50,
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) => SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(
                    _abbreviateRp(value),
                    style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= _chartData.length) return const SizedBox();
                  final date = _chartData[idx]['date'] as DateTime;
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(
                      DateFormat('dd/MM').format(date),
                      style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.w500),
                    ),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              preventCurveOverShooting: true,
              curveSmoothness: 0.35,
              gradient: const LinearGradient(
                colors: [Colors.pink, Colors.purple],
              ),
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                  radius: 4,
                  color: Colors.white,
                  strokeWidth: 2,
                  strokeColor: Colors.pink,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [Colors.pink.withValues(alpha: 0.2), Colors.pink.withValues(alpha: 0.0)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTransactionsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Transaksi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        TextButton.icon(
          onPressed: _exportExcel,
          icon: const Icon(Icons.file_download, size: 18),
          label: const Text('Ekspor'),
          style: TextButton.styleFrom(foregroundColor: Colors.pink),
        ),
      ],
    );
  }

  Widget _buildFiltersRow() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Cari invoice/kasir...',
              prefixIcon: const Icon(Icons.search, size: 20, color: Colors.pink),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              filled: true,
              fillColor: Colors.pink.shade50.withValues(alpha: 0.2),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
              });
              _fetchDailyReport();
            },
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.pink.shade50.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.pink.shade100),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedPaymentMethod,
              items: const [
                DropdownMenuItem(value: 'semua', child: Text('Semua')),
                DropdownMenuItem(value: 'tunai', child: Text('Tunai')),
                DropdownMenuItem(value: 'qris', child: Text('QRIS')),
                DropdownMenuItem(value: 'transfer', child: Text('Transfer')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedPaymentMethod = val;
                  });
                  _fetchDailyReport();
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  void _showTransactionDetails(Map<String, dynamic> tx) {
    final details = tx['details'] as List? ?? [];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tx['invoice_number'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 4),
            Text(tx['formatted_date'] ?? '', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Divider(),
                const Text('Daftar Produk', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF880E4F))),
                const SizedBox(height: 8),
                ...details.map((d) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${d['product_name'] ?? (d['product'] != null ? d['product']['name'] : 'Produk')} x${d['qty']}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        Text(
                          'Rp ${_formatRp(d['subtotal'])}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  );
                }),
                const Divider(height: 24),
                _buildDetailRow('Kasir', tx['user_name'] ?? 'Tidak Diketahui'),
                _buildDetailRow('Cabang', tx['branch_name'] ?? 'Tidak Diketahui'),
                const Divider(height: 24),
                _buildDetailRow('Metode Pembayaran', (tx['payment_method'] ?? 'Tunai').toString().toUpperCase(), isBold: true),
                if (tx['payment_method'] == 'tunai') ...[
                  _buildDetailRow('Uang Diterima', 'Rp ${_formatRp(tx['payment_amount'])}'),
                  _buildDetailRow('Kembalian', 'Rp ${_formatRp(tx['change_amount'])}', color: Colors.green.shade800),
                ],
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Transaksi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF880E4F))),
                    Text(
                      'Rp ${_formatRp(tx['total'])}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.pink),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsList() {
    final transactions = _reportData?['transactions'] as List? ?? [];
    if (transactions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40.0),
          child: Text('Tidak ada transaksi ditemukan'),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: transactions.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final tx = transactions[i];
        final methodStr = (tx['payment_method'] ?? 'Tunai').toString().toUpperCase();
        final details = tx['details'] as List? ?? [];
        final itemsSummary = details.isEmpty
            ? 'Tidak ada produk'
            : details.map((d) {
                final pName = d['product_name'] ?? (d['product'] != null ? d['product']['name'] : 'Produk');
                final qty = d['qty'] ?? 1;
                return '$pName (x$qty)';
              }).join(', ');

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.pink.shade50),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            onTap: () => _showTransactionDetails(tx),
            leading: CircleAvatar(
              backgroundColor: Colors.pink.shade50,
              child: const Icon(Icons.receipt_long, color: Colors.pink, size: 20),
            ),
            title: Text(tx['invoice_number'], 
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  itemsSummary,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12, fontWeight: FontWeight.w500),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(tx['formatted_date'] ?? '', style: const TextStyle(fontSize: 11)),
                    if (tx['user_name'] != null) ...[
                      const SizedBox(width: 8),
                      Text('•  ${tx['user_name']}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    ],
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.pink.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        methodStr,
                        style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.pink),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: Text('Rp ${_formatRp(tx['total'])}', 
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.pink)),
          ),
        );
      },
    );
  }
}
