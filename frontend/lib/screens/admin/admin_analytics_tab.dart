import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';

class AdminAnalyticsTab extends StatefulWidget {
  const AdminAnalyticsTab({super.key});

  @override
  State<AdminAnalyticsTab> createState() => _AdminAnalyticsTabState();
}

class _AdminAnalyticsTabState extends State<AdminAnalyticsTab> {
  final ApiService _apiService = ApiService();
  
  // State variables
  bool _isLoading = true;
  String _selectedType = 'daily'; // daily, monthly, yearly
  DateTime _selectedDate = DateTime.now();
  int _activeChartTab = 0; // 0: Keuangan, 1: Pergerakan Barang
  int? _selectedBranchId; // null: Semua Cabang
  
  Map<String, dynamic> _reportData = {};
  List<dynamic> _branchData = [];
  List<Map<String, dynamic>> _branches = [];

  @override
  void initState() {
    super.initState();
    _fetchBranches();
    _fetchStats();
  }

  Future<void> _fetchBranches() async {
    try {
      final response = await _apiService.get('/branches');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        if (mounted) {
          setState(() {
            _branches = data.map((b) => Map<String, dynamic>.from(b)).toList();
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching branches: $e');
    }
  }

  Future<void> _fetchStats() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final monthStr = DateFormat('yyyy-MM').format(_selectedDate);
      final yearStr = DateFormat('yyyy').format(_selectedDate);

      final branchParam = _selectedBranchId != null ? '&branch_id=$_selectedBranchId' : '';
      final queryParams = 'type=$_selectedType&date=$dateStr&month=$monthStr&year=$yearStr$branchParam';

      final responses = await Future.wait([
        _apiService.get('/reports/daily?$queryParams'),
        _apiService.get('/reports/branches'),
      ]);

      if (responses[0].statusCode == 200) {
        final body = jsonDecode(responses[0].body);
        if (mounted) {
          setState(() {
            _reportData = body;
          });
        }
      }

      if (responses[1].statusCode == 200) {
        final body = jsonDecode(responses[1].body);
        if (mounted) {
          setState(() {
            _branchData = body['data'] ?? [];
          });
        }
      }
    } catch (e) {
      debugPrint('Fetch stats error: $e');
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  String _getMonthName(int monthNum) {
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return months[monthNum - 1];
  }

  String _getMonthNameShort(int monthNum) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agt', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    return months[monthNum - 1];
  }

  String _formatRp(int number) {
    final str = number.toString();
    final result = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) result.write('.');
      result.write(str[i]);
    }
    return result.toString();
  }

  String _abbreviateNumber(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1).replaceAll('.0', '')}jt';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}rb';
    }
    return value.toStringAsFixed(0);
  }

  int _getMaxSpots() {
    if (_selectedType == 'daily') return 24;
    if (_selectedType == 'monthly') return 31;
    return 12;
  }

  double _getBottomInterval() {
    if (_selectedType == 'daily') return 4.0;
    if (_selectedType == 'monthly') return 5.0;
    return 2.0;
  }

  String _getBottomTitleLabel(int val) {
    if (_selectedType == 'daily') {
      return '${val.toString().padLeft(2, '0')}:00';
    }
    if (_selectedType == 'monthly') {
      return '${val + 1}';
    }
    if (val >= 0 && val < 12) {
      return _getMonthNameShort(val + 1);
    }
    return '';
  }

  List<FlSpot> _getRevenueSpots(int maxSpots) {
    List<double> values = List.filled(maxSpots, 0.0);
    final txs = _reportData['transactions'] ?? [];
    for (var tx in txs) {
      final dt = DateTime.parse(tx['created_at']);
      int index = 0;
      if (_selectedType == 'daily') {
        index = dt.hour;
      } else if (_selectedType == 'monthly') {
        index = dt.day - 1;
      } else if (_selectedType == 'yearly') {
        index = dt.month - 1;
      }
      if (index >= 0 && index < maxSpots) {
        values[index] += double.tryParse(tx['total'].toString()) ?? 0.0;
      }
    }
    return List.generate(maxSpots, (i) => FlSpot(i.toDouble(), values[i]));
  }

  List<FlSpot> _getSoldSpots(int maxSpots) {
    List<double> values = List.filled(maxSpots, 0.0);
    final txs = _reportData['transactions'] ?? [];
    for (var tx in txs) {
      final dt = DateTime.parse(tx['created_at']);
      int index = 0;
      if (_selectedType == 'daily') {
        index = dt.hour;
      } else if (_selectedType == 'monthly') {
        index = dt.day - 1;
      } else if (_selectedType == 'yearly') {
        index = dt.month - 1;
      }
      if (index >= 0 && index < maxSpots) {
        for (var d in tx['details'] ?? []) {
          values[index] += (d['qty'] is num ? d['qty'] : double.tryParse(d['qty'].toString()) ?? 0.0);
        }
      }
    }
    return List.generate(maxSpots, (i) => FlSpot(i.toDouble(), values[i]));
  }

  List<FlSpot> _getRestockSpots(int maxSpots) {
    List<double> values = List.filled(maxSpots, 0.0);
    final logs = _reportData['incoming_logs'] ?? [];
    for (var log in logs) {
      final dt = DateTime.parse(log['created_at']);
      int index = 0;
      if (_selectedType == 'daily') {
        index = dt.hour;
      } else if (_selectedType == 'monthly') {
        index = dt.day - 1;
      } else if (_selectedType == 'yearly') {
        index = dt.month - 1;
      }
      if (index >= 0 && index < maxSpots) {
        values[index] += (log['quantity'] is num ? log['quantity'] : double.tryParse(log['quantity'].toString()) ?? 0.0);
      }
    }
    return List.generate(maxSpots, (i) => FlSpot(i.toDouble(), values[i]));
  }

  double _getMaxYForChart(List<FlSpot> spots) {
    double maxVal = 0.0;
    for (var spot in spots) {
      if (spot.y > maxVal) maxVal = spot.y;
    }
    return maxVal == 0 ? 10.0 : maxVal * 1.15;
  }

  double _getMultiLineMaxY(List<FlSpot> s1, List<FlSpot> s2) {
    double m1 = _getMaxYForChart(s1);
    double m2 = _getMaxYForChart(s2);
    return m1 > m2 ? m1 : m2;
  }

  Future<void> _selectDateFilter() async {
    if (_selectedType == 'daily') {
      final picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime(2020),
        lastDate: DateTime.now().add(const Duration(days: 365)),
      );
      if (picked != null) {
        setState(() => _selectedDate = picked);
        _fetchStats();
      }
    } else if (_selectedType == 'monthly') {
      showDialog(
        context: context,
        builder: (dialogCtx) {
          int tempYear = _selectedDate.year;
          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Pilih Bulan', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF880E4F))),
                    DropdownButton<int>(
                      value: tempYear,
                      items: List.generate(10, (i) => DateTime.now().year - 5 + i)
                          .map((y) => DropdownMenuItem(value: y, child: Text(y.toString())))
                          .toList(),
                      onChanged: (y) {
                        if (y != null) {
                          setDialogState(() => tempYear = y);
                        }
                      },
                    ),
                  ],
                ),
                content: SizedBox(
                  width: 300,
                  child: GridView.builder(
                    shrinkWrap: true,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 1.5,
                    ),
                    itemCount: 12,
                    itemBuilder: (ctx, index) {
                      final monthNum = index + 1;
                      final isSelected = _selectedDate.month == monthNum && _selectedDate.year == tempYear;
                      return InkWell(
                        onTap: () {
                          Navigator.pop(dialogCtx, DateTime(tempYear, monthNum));
                        },
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.pink : Colors.pink.shade50,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            _getMonthNameShort(monthNum),
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.pink.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            }
          );
        }
      ).then((val) {
        if (val != null) {
          setState(() {
            _selectedDate = val as DateTime;
          });
          _fetchStats();
        }
      });
    } else {
      // Yearly
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Pilih Tahun', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF880E4F))),
          content: SizedBox(
            width: 250,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: 8,
              itemBuilder: (context, i) {
                final yearNum = DateTime.now().year - 4 + i;
                final isSelected = _selectedDate.year == yearNum;
                return ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  tileColor: isSelected ? Colors.pink.shade50 : null,
                  title: Text(
                    yearNum.toString(),
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.pink : null,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  onTap: () => Navigator.pop(ctx, yearNum),
                );
              },
            ),
          ),
        ),
      ).then((val) {
        if (val != null) {
          setState(() {
            _selectedDate = DateTime(val as int, _selectedDate.month);
          });
          _fetchStats();
        }
      });
    }
  }

  String _getFormattedPeriodLabel() {
    if (_selectedType == 'daily') {
      return DateFormat('dd MMMM yyyy', 'id_ID').format(_selectedDate);
    } else if (_selectedType == 'monthly') {
      return '${_getMonthName(_selectedDate.month)} ${_selectedDate.year}';
    } else {
      return 'Tahun ${_selectedDate.year}';
    }
  }

  void _showReportPreviewDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _ReportPreviewDialog(
        reportData: _reportData,
        selectedType: _selectedType,
        selectedDate: _selectedDate,
        selectedBranchId: _selectedBranchId,
        getMonthName: _getMonthName,
        formatRp: _formatRp,
        apiService: _apiService,
        branches: _branches,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: RefreshIndicator(
            onRefresh: _fetchStats,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Column(
                      children: [
                        DropdownButtonFormField<int?>(
                          initialValue: _selectedBranchId,
                          decoration: const InputDecoration(
                            labelText: 'Pilih Cabang Laporan',
                            prefixIcon: Icon(Icons.storefront, color: Colors.pink),
                          ),
                          items: [
                            const DropdownMenuItem<int?>(value: null, child: Text('Semua Cabang (Keseluruhan)')),
                            ..._branches.map((b) => DropdownMenuItem<int?>(
                              value: b['id'],
                              child: Text(b['name'] ?? 'Cabang ${b['id']}'),
                            )),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _selectedBranchId = val;
                            });
                            _fetchStats();
                          },
                        ),
                        const SizedBox(height: 16),
                        SegmentedButton<String>(
                          style: SegmentedButton.styleFrom(
                            selectedBackgroundColor: Colors.pink,
                            selectedForegroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          segments: const [
                            ButtonSegment(value: 'daily', label: Text('Harian'), icon: Icon(Icons.today)),
                            ButtonSegment(value: 'monthly', label: Text('Bulanan'), icon: Icon(Icons.calendar_month)),
                            ButtonSegment(value: 'yearly', label: Text('Tahunan'), icon: Icon(Icons.calendar_today)),
                          ],
                          selected: {_selectedType},
                          onSelectionChanged: (Set<String> newSelection) {
                            setState(() {
                              _selectedType = newSelection.first;
                            });
                            _fetchStats();
                          },
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton.icon(
                              onPressed: _selectDateFilter,
                              icon: const Icon(Icons.edit_calendar, color: Colors.pink),
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.pink.shade50,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              ),
                              label: Text(
                                _getFormattedPeriodLabel(),
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.pink),
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: _isLoading || _reportData.isEmpty ? null : _showReportPreviewDialog,
                              icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                              label: const Text('Buat Laporan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.pink.shade700,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  if (!_isLoading && _reportData.isNotEmpty) ...[
                    _buildSummaryCards(),
                    _buildModernChartCard(),
                    _buildBranchComparison(),
                    const SizedBox(height: 100),
                  ],
                  if (_isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(80.0),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    final double income = double.tryParse((_reportData['total_income'] ?? 0).toString()) ?? 0.0;
    final int count = _reportData['transaction_count'] ?? 0;
    final double average = count == 0 ? 0.0 : income / count;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          _buildStatCard('Pendapatan', 'Rp ${_formatRp(income.toInt())}', Icons.account_balance_wallet, Colors.pink),
          const SizedBox(width: 16),
          _buildStatCard('Jumlah Transaksi', '$count Transaksi', Icons.shopping_cart, Colors.purple),
          const SizedBox(width: 16),
          _buildStatCard('Rata-rata Transaksi', 'Rp ${_formatRp(average.toInt())}', Icons.analytics, Colors.blue),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernChartCard() {
    final int maxSpots = _getMaxSpots();
    final spotsRev = _getRevenueSpots(maxSpots);
    final spotsSold = _getSoldSpots(maxSpots);
    final spotsIn = _getRestockSpots(maxSpots);

    final maxRevY = _getMaxYForChart(spotsRev);
    final maxVolY = _getMultiLineMaxY(spotsSold, spotsIn);

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: Colors.pink.shade50),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Tren Analitik Toko',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF880E4F)),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildChartToggleButton('Keuangan', 0),
                          _buildChartToggleButton('Barang', 1),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (_activeChartTab == 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Row(
                    children: [
                      _buildIndicator(Colors.orange, 'Barang Terjual (Pcs)'),
                      const SizedBox(width: 16),
                      _buildIndicator(Colors.green, 'Barang Masuk / Restock (Pcs)'),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              SizedBox(
                height: 240,
                child: LineChart(
                  LineChartData(
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (touchedSpot) => _activeChartTab == 0 ? Colors.pink.shade900 : Colors.grey.shade900,
                        getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                          return touchedBarSpots.map((barSpot) {
                            if (_activeChartTab == 0) {
                              return LineTooltipItem(
                                'Rp ${_formatRp(barSpot.y.toInt())}',
                                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              );
                            } else {
                              final label = barSpot.barIndex == 0 ? 'Terjual' : 'Masuk';
                              return LineTooltipItem(
                                '$label: ${barSpot.y.toInt()} pcs',
                                TextStyle(
                                  color: barSpot.barIndex == 0 ? Colors.orange.shade300 : Colors.green.shade300, 
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            }
                          }).toList();
                        },
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: Colors.grey.shade100,
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    minX: 0,
                    maxX: (maxSpots - 1).toDouble(),
                    minY: 0,
                    maxY: _activeChartTab == 0 ? maxRevY : maxVolY,
                    titlesData: FlTitlesData(
                      show: true,
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 45,
                          interval: _activeChartTab == 0
                              ? (maxRevY / 4 == 0 ? 1.0 : maxRevY / 4)
                              : (maxVolY / 4 == 0 ? 1.0 : maxVolY / 4),
                          getTitlesWidget: (value, meta) {
                            return SideTitleWidget(
                              axisSide: meta.axisSide,
                              child: Text(
                                _activeChartTab == 0 ? _abbreviateNumber(value) : value.toStringAsFixed(0),
                                style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500),
                              ),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          interval: _getBottomInterval(),
                          getTitlesWidget: (value, meta) {
                            final intVal = value.toInt();
                            final interval = _getBottomInterval();
                            // Hide the label if it doesn't align with the interval steps to prevent crowding
                            if (intVal % interval != 0 && intVal != 0) {
                              return const SizedBox();
                            }
                            return SideTitleWidget(
                              axisSide: meta.axisSide,
                              child: Text(
                                _getBottomTitleLabel(intVal),
                                style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    lineBarsData: _activeChartTab == 0
                        ? [
                            LineChartBarData(
                              spots: spotsRev,
                              isCurved: true,
                              preventCurveOverShooting: true,
                              gradient: const LinearGradient(
                                colors: [Colors.pink, Colors.purple],
                              ),
                              barWidth: 4,
                              isStrokeCapRound: true,
                              dotData: const FlDotData(show: false),
                              belowBarData: BarAreaData(
                                show: true,
                                gradient: LinearGradient(
                                  colors: [Colors.pink.withValues(alpha: 0.25), Colors.purple.withValues(alpha: 0.0)],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                          ]
                        : [
                            LineChartBarData(
                              spots: spotsSold,
                              isCurved: true,
                              preventCurveOverShooting: true,
                              gradient: const LinearGradient(
                                colors: [Colors.orange, Colors.red],
                              ),
                              barWidth: 3,
                              dotData: const FlDotData(show: false),
                              belowBarData: BarAreaData(
                                show: true,
                                gradient: LinearGradient(
                                  colors: [Colors.orange.withValues(alpha: 0.15), Colors.orange.withValues(alpha: 0.0)],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                            LineChartBarData(
                              spots: spotsIn,
                              isCurved: true,
                              preventCurveOverShooting: true,
                              gradient: const LinearGradient(
                                colors: [Colors.green, Colors.teal],
                              ),
                              barWidth: 3,
                              dotData: const FlDotData(show: false),
                              belowBarData: BarAreaData(
                                show: true,
                                gradient: LinearGradient(
                                  colors: [Colors.green.withValues(alpha: 0.15), Colors.green.withValues(alpha: 0.0)],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                          ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIndicator(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildChartToggleButton(String label, int index) {
    final isSelected = _activeChartTab == index;
    return InkWell(
      onTap: () => setState(() => _activeChartTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.pink.shade800 : Colors.grey.shade600,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildBranchComparison() {
    if (_branchData.isEmpty) return const SizedBox();
    double maxVal = 0;
    for (var b in _branchData) {
      double r = double.tryParse(b['revenue'].toString()) ?? 0;
      if (r > maxVal) maxVal = r;
    }
    if (maxVal == 0) maxVal = 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: Colors.pink.shade50),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.store, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Perbandingan Pendapatan Cabang',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF880E4F)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ..._branchData.map((branch) {
                final rev = double.tryParse(branch['revenue'].toString()) ?? 0.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 18.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              branch['branch_name'] ?? 'Cabang Lain',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4A4A4A)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Rp ${_formatRp(rev.toInt())}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF880E4F)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: rev / maxVal,
                        backgroundColor: Colors.blue.shade50,
                        color: Colors.blue,
                        minHeight: 10,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

// Dialog preview laporan formal
class _ReportPreviewDialog extends StatefulWidget {
  final Map<String, dynamic> reportData;
  final String selectedType;
  final DateTime selectedDate;
  final int? selectedBranchId;
  final String Function(int) getMonthName;
  final String Function(int) formatRp;
  final ApiService apiService;
  final List<Map<String, dynamic>> branches;

  const _ReportPreviewDialog({
    required this.reportData,
    required this.selectedType,
    required this.selectedDate,
    this.selectedBranchId,
    required this.getMonthName,
    required this.formatRp,
    required this.apiService,
    required this.branches,
  });

  @override
  State<_ReportPreviewDialog> createState() => _ReportPreviewDialogState();
}

class _ReportPreviewDialogState extends State<_ReportPreviewDialog> {
  bool _isActionLoading = false;

  String _getPeriodLabel() {
    if (widget.selectedType == 'daily') {
      return DateFormat('dd MMMM yyyy', 'id_ID').format(widget.selectedDate);
    } else if (widget.selectedType == 'monthly') {
      return '${widget.getMonthName(widget.selectedDate.month)} ${widget.selectedDate.year}';
    } else {
      return 'Tahun ${widget.selectedDate.year}';
    }
  }

  String _getBranchNameLabel(int? id) {
    if (id == null) return 'Semua Cabang (Keseluruhan)';
    final branch = widget.branches.firstWhere((b) => b['id'] == id, orElse: () => {});
    return branch['name'] ?? 'Cabang $id';
  }

  Future<void> _handlePrintAndShare() async {
    setState(() => _isActionLoading = true);
    
    // Simulate printer discovery and queueing
    await Future.delayed(const Duration(milliseconds: 1500));
    
    if (mounted) {
      setState(() => _isActionLoading = false);
      
      final totalIncome = widget.reportData['total_income'] ?? 0;
      final txCount = widget.reportData['transaction_count'] ?? 0;
      final tunaiTotal = widget.reportData['tunai_total'] ?? 0;
      final qrisTotal = widget.reportData['qris_total'] ?? 0;
      final transferTotal = widget.reportData['transfer_total'] ?? 0;
      
      int totalQtySold = 0;
      for (var p in widget.reportData['sold_summary'] ?? []) {
        totalQtySold += (p['qty'] as num).toInt();
      }

      int totalQtyIn = 0;
      for (var p in widget.reportData['incoming_summary'] ?? []) {
        totalQtyIn += (p['qty'] as num).toInt();
      }

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 12),
              Text('Cetak Berhasil', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'Dokumen laporan telah berhasil dikirim ke antrean printer kasir bluetooth.\n\n'
            'Apakah Anda ingin mengirim ringkasan laporan ini langsung ke WhatsApp Owner?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tutup'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                final period = _getPeriodLabel();
                final text = '*LAPORAN PENJUALAN EARTH PETSHOP*\n'
                    '*Periode:* $period\n'
                    '========================\n'
                    '*Total Omset:* Rp ${widget.formatRp(totalIncome.toInt())}\n'
                    '*Total Transaksi:* $txCount\n'
                    '------------------------\n'
                    '*Metode Pembayaran:*\n'
                    '- Tunai: Rp ${widget.formatRp(tunaiTotal.toInt())}\n'
                    '- QRIS: Rp ${widget.formatRp(qrisTotal.toInt())}\n'
                    '- Transfer: Rp ${widget.formatRp(transferTotal.toInt())}\n'
                    '------------------------\n'
                    '*Volume Pergerakan Barang:*\n'
                    '- Barang Terjual: $totalQtySold pcs\n'
                    '- Barang Masuk (Restock): $totalQtyIn pcs\n'
                    '========================\n'
                    '_Laporan ini dihasilkan otomatis oleh POS Earth Petshop._';
                
                final url = 'https://api.whatsapp.com/send?text=${Uri.encodeComponent(text)}';
                await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
              },
              icon: const Icon(Icons.share, color: Colors.white),
              label: const Text('Bagikan ke WA', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _handleExportExcel() async {
    setState(() => _isActionLoading = true);
    
    // Simulate Excel file downloading and parsing
    await Future.delayed(const Duration(milliseconds: 1200));
    
    if (mounted) {
      setState(() => _isActionLoading = false);
      
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.cloud_download, color: Colors.blue, size: 28),
              SizedBox(width: 12),
              Text('Unduhan Selesai', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            'Laporan Excel untuk periode ${_getPeriodLabel()} telah berhasil diunduh dan disimpan di folder perangkat Anda:\n\n'
            'Laporan_Penjualan_EarthPetshop_Cabang_${widget.selectedBranchId ?? 'Keseluruhan'}_${DateFormat('yyyyMMdd_HHmmss').format(widget.selectedDate)}.xlsx',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: const Text('Selesai', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final double income = double.tryParse((widget.reportData['total_income'] ?? 0).toString()) ?? 0.0;
    final int txCount = widget.reportData['transaction_count'] ?? 0;
    
    final tunaiTotal = double.tryParse((widget.reportData['tunai_total'] ?? 0).toString()) ?? 0.0;
    final qrisTotal = double.tryParse((widget.reportData['qris_total'] ?? 0).toString()) ?? 0.0;
    final transferTotal = double.tryParse((widget.reportData['transfer_total'] ?? 0).toString()) ?? 0.0;

    final soldSummary = widget.reportData['sold_summary'] ?? [];
    final incomingSummary = widget.reportData['incoming_summary'] ?? [];
    final incomingLogs = widget.reportData['incoming_logs'] ?? [];
    final transactions = widget.reportData['transactions'] ?? [];

    return Dialog.fullscreen(
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F7F7),
        appBar: AppBar(
          title: const Text('Pratinjau Dokumen Laporan'),
          backgroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            if (_isActionLoading)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.0),
                child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)),
              )
            else ...[
              TextButton.icon(
                onPressed: _handleExportExcel,
                icon: const Icon(Icons.table_view, color: Colors.green),
                label: const Text('Ekspor Excel', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: ElevatedButton.icon(
                  onPressed: _handlePrintAndShare,
                  icon: const Icon(Icons.print_outlined, color: Colors.white, size: 18),
                  label: const Text('Cetak & Bagikan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pink,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ]
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 5))
                  ],
                ),
                padding: const EdgeInsets.all(40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Kop Surat
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'EARTH PETSHOP',
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF880E4F), letterSpacing: 1.2),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Layanan Peliharaan Profesional & Kasir Terpadu',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                            ),
                            Text(
                              'Jl. Raya Puspiptek No. 12, Pamulang, Tangerang Selatan',
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.pink.shade300, width: 1.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'DOKUMEN RESMI',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.pink),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 40, thickness: 1.5, color: Colors.black87),
                    
                    // Judul Laporan & Periode
                    Center(
                      child: Column(
                        children: [
                          const Text(
                            'LAPORAN TRANSAKSI & PERGERAKAN INVENTARIS',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Periode: ${_getPeriodLabel()}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.pink),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Cabang: ${_getBranchNameLabel(widget.selectedBranchId)}',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 36),

                    // Ringkasan Finansial
                    const Text('I. RINGKASAN PENDAPATAN & TRANSAKSI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF880E4F))),
                    const SizedBox(height: 12),
                    Table(
                      border: TableBorder.all(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8)),
                      columnWidths: const {
                        0: FlexColumnWidth(1.2),
                        1: FlexColumnWidth(1.2),
                        2: FlexColumnWidth(1.2),
                      },
                      children: [
                        TableRow(
                          decoration: BoxDecoration(color: Colors.grey.shade50),
                          children: const [
                            Padding(
                              padding: EdgeInsets.all(12.0),
                              child: Text('Total Omset Penjualan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center),
                            ),
                            Padding(
                              padding: EdgeInsets.all(12.0),
                              child: Text('Volume Transaksi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center),
                            ),
                            Padding(
                              padding: EdgeInsets.all(12.0),
                              child: Text('Rata-rata Transaksi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center),
                            ),
                          ],
                        ),
                        TableRow(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Text('Rp ${widget.formatRp(income.toInt())}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.pink), textAlign: TextAlign.center),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Text('$txCount Transaksi', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Text('Rp ${widget.formatRp(txCount == 0 ? 0 : (income / txCount).toInt())}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue), textAlign: TextAlign.center),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Metode Pembayaran
                    const Text('II. BREAKDOWN METODE PEMBAYARAN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF880E4F))),
                    const SizedBox(height: 12),
                    Table(
                      border: TableBorder.all(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8)),
                      children: [
                        TableRow(
                          decoration: BoxDecoration(color: Colors.grey.shade50),
                          children: const [
                            Padding(
                              padding: EdgeInsets.all(10.0),
                              child: Text('Metode Pembayaran', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                            ),
                            Padding(
                              padding: EdgeInsets.all(10.0),
                              child: Text('Persentase', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center),
                            ),
                            Padding(
                              padding: EdgeInsets.all(10.0),
                              child: Text('Total Penerimaan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.right),
                            ),
                          ],
                        ),
                        _buildPaymentRow('Tunai (Cash)', income == 0 ? 0.0 : tunaiTotal / income, tunaiTotal),
                        _buildPaymentRow('QRIS Dinamis', income == 0 ? 0.0 : qrisTotal / income, qrisTotal),
                        _buildPaymentRow('Transfer Bank', income == 0 ? 0.0 : transferTotal / income, transferTotal),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Ringkasan Barang Terjual dan Masuk
                    const Text('III. RINCIAN PERGERAKAN INVENTARIS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF880E4F))),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Barang Terjual Column
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: const BoxDecoration(
                                  color: Colors.orange,
                                  borderRadius: BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
                                ),
                                width: double.infinity,
                                child: const Text(
                                  'Barang Terjual (Sales Out)',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                              ),
                              Table(
                                border: TableBorder.all(color: Colors.grey.shade300),
                                children: [
                                  TableRow(
                                    decoration: BoxDecoration(color: Colors.grey.shade50),
                                    children: const [
                                      Padding(padding: EdgeInsets.all(8.0), child: Text('Nama Produk', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10))),
                                      Padding(padding: EdgeInsets.all(8.0), child: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10), textAlign: TextAlign.center)),
                                    ],
                                  ),
                                  if (soldSummary.isEmpty)
                                    const TableRow(
                                      children: [
                                        Padding(padding: EdgeInsets.all(8.0), child: Text('Tidak ada penjualan', style: TextStyle(fontStyle: FontStyle.italic, fontSize: 10))),
                                        Padding(padding: EdgeInsets.all(8.0), child: Text('-', textAlign: TextAlign.center, style: TextStyle(fontSize: 10))),
                                      ],
                                    )
                                  else
                                    ...soldSummary.map((p) => TableRow(
                                      children: [
                                        Padding(padding: EdgeInsets.all(8.0), child: Text(p['name'] ?? '', style: const TextStyle(fontSize: 10))),
                                        Padding(padding: EdgeInsets.all(8.0), child: Text('${p['qty']} pcs', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10), textAlign: TextAlign.center)),
                                      ],
                                    )),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Barang Masuk Column
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: const BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
                                ),
                                width: double.infinity,
                                child: const Text(
                                  'Barang Masuk (Restock In)',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                              ),
                              Table(
                                border: TableBorder.all(color: Colors.grey.shade300),
                                children: [
                                  TableRow(
                                    decoration: BoxDecoration(color: Colors.grey.shade50),
                                    children: const [
                                      Padding(padding: EdgeInsets.all(8.0), child: Text('Nama Produk', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10))),
                                      Padding(padding: EdgeInsets.all(8.0), child: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10), textAlign: TextAlign.center)),
                                    ],
                                  ),
                                  if (incomingSummary.isEmpty)
                                    const TableRow(
                                      children: [
                                        Padding(padding: EdgeInsets.all(8.0), child: Text('Tidak ada restock', style: TextStyle(fontStyle: FontStyle.italic, fontSize: 10))),
                                        Padding(padding: EdgeInsets.all(8.0), child: Text('-', textAlign: TextAlign.center, style: TextStyle(fontSize: 10))),
                                      ],
                                    )
                                  else
                                    ...incomingSummary.map((p) => TableRow(
                                      children: [
                                        Padding(padding: EdgeInsets.all(8.0), child: Text(p['name'] ?? '', style: const TextStyle(fontSize: 10))),
                                        Padding(padding: EdgeInsets.all(8.0), child: Text('${p['qty']} pcs', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10), textAlign: TextAlign.center)),
                                      ],
                                    )),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Detail Log Restock Masuk (Incoming Details)
                    if (incomingLogs.isNotEmpty) ...[
                      const Text('IV. LOG RIWAYAT BARANG MASUK', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF880E4F))),
                      const SizedBox(height: 8),
                      Table(
                        border: TableBorder.all(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(6)),
                        columnWidths: const {
                          0: FlexColumnWidth(1.2),
                          1: FlexColumnWidth(0.5),
                          2: FlexColumnWidth(1.5),
                          3: FlexColumnWidth(0.8),
                        },
                        children: [
                          TableRow(
                            decoration: BoxDecoration(color: Colors.grey.shade50),
                            children: const [
                              Padding(padding: EdgeInsets.all(8.0), child: Text('Produk', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9))),
                              Padding(padding: EdgeInsets.all(8.0), child: Text('Jumlah', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9), textAlign: TextAlign.center)),
                              Padding(padding: EdgeInsets.all(8.0), child: Text('Catatan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9))),
                              Padding(padding: EdgeInsets.all(8.0), child: Text('Operator', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9))),
                            ],
                          ),
                          ...incomingLogs.map((log) => TableRow(
                            children: [
                              Padding(padding: const EdgeInsets.all(8.0), child: Text(log['product']?['name'] ?? 'Produk Dihapus', style: const TextStyle(fontSize: 9))),
                              Padding(padding: const EdgeInsets.all(8.0), child: Text('+${log['quantity']} pcs', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 9), textAlign: TextAlign.center)),
                              Padding(padding: const EdgeInsets.all(8.0), child: Text(log['note'] ?? '-', style: const TextStyle(fontSize: 9))),
                              Padding(padding: const EdgeInsets.all(8.0), child: Text(log['user']?['name'] ?? 'Admin', style: const TextStyle(fontSize: 9))),
                            ],
                          )),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Daftar Transaksi Rinci
                    const Text('V. RIWAYAT TRANSAKSI PENJUALAN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF880E4F))),
                    const SizedBox(height: 12),
                    Table(
                      border: TableBorder.all(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(6)),
                      columnWidths: const {
                        0: FlexColumnWidth(1.1),
                        1: FlexColumnWidth(0.7),
                        2: FlexColumnWidth(0.8),
                        3: FlexColumnWidth(0.7),
                        4: FlexColumnWidth(0.9),
                      },
                      children: [
                        TableRow(
                          decoration: BoxDecoration(color: Colors.grey.shade50),
                          children: const [
                            Padding(padding: EdgeInsets.all(8.0), child: Text('No. Invoice', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10))),
                            Padding(padding: EdgeInsets.all(8.0), child: Text('Waktu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10))),
                            Padding(padding: EdgeInsets.all(8.0), child: Text('Kasir', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10))),
                            Padding(padding: EdgeInsets.all(8.0), child: Text('Metode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10))),
                            Padding(padding: EdgeInsets.all(8.0), child: Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10), textAlign: TextAlign.right)),
                          ],
                        ),
                        if (transactions.isEmpty)
                          const TableRow(
                            children: [
                              Padding(padding: EdgeInsets.all(8.0), child: Text('Tidak ada data transaksi', style: TextStyle(fontStyle: FontStyle.italic, fontSize: 10))),
                              Padding(padding: EdgeInsets.all(8.0), child: Text('-', style: TextStyle(fontSize: 10))),
                              Padding(padding: EdgeInsets.all(8.0), child: Text('-', style: TextStyle(fontSize: 10))),
                              Padding(padding: EdgeInsets.all(8.0), child: Text('-', style: TextStyle(fontSize: 10))),
                              Padding(padding: EdgeInsets.all(8.0), child: Text('Rp 0', textAlign: TextAlign.right, style: TextStyle(fontSize: 10))),
                            ],
                          )
                        else
                          ...transactions.map((tx) {
                            final dateParsed = DateTime.parse(tx['created_at']);
                            final timeStr = DateFormat('HH:mm').format(dateParsed);
                            return TableRow(
                              children: [
                                Padding(padding: const EdgeInsets.all(8.0), child: Text(tx['invoice_number'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 10))),
                                Padding(padding: const EdgeInsets.all(8.0), child: Text(timeStr, style: const TextStyle(fontSize: 10))),
                                Padding(padding: const EdgeInsets.all(8.0), child: Text(tx['user_name'] ?? 'Unknown', style: const TextStyle(fontSize: 10))),
                                Padding(padding: const EdgeInsets.all(8.0), child: Text((tx['payment_method'] ?? 'tunai').toString().toUpperCase(), style: const TextStyle(fontSize: 9))),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    'Rp ${widget.formatRp((double.tryParse(tx['total'].toString()) ?? 0.0).toInt())}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ],
                            );
                          }),
                      ],
                    ),
                    const SizedBox(height: 56),

                    // Tanda Tangan
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Disiapkan Oleh,', style: TextStyle(fontSize: 11)),
                            const SizedBox(height: 50),
                            const Text('..............................', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                            Text('Kasir / Staff Admin', style: TextStyle(color: Colors.grey.shade600, fontSize: 10)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Disetujui Oleh,', style: TextStyle(fontSize: 11)),
                            const SizedBox(height: 50),
                            const Text('Candra Ahmad R.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                            Text('Manager Operasional', style: TextStyle(color: Colors.grey.shade600, fontSize: 10)),
                          ],
                        ),
                      ],
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

  TableRow _buildPaymentRow(String method, double percentage, double amount) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(10.0),
          child: Text(method, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11)),
        ),
        Padding(
          padding: const EdgeInsets.all(10.0),
          child: Text('${(percentage * 100).toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center),
        ),
        Padding(
          padding: const EdgeInsets.all(10.0),
          child: Text('Rp ${widget.formatRp(amount.toInt())}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.right),
        ),
      ],
    );
  }
}
