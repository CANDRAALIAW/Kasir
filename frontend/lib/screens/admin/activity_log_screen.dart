import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import 'dart:convert';

class ActivityLogScreen extends StatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.get('/activity-logs');
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        setState(() {
          _logs = body['data'] ?? [];
        });
      }
    } catch (e) {
      debugPrint('Fetch logs error: $e');
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Log Audit Keamanan')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _fetchLogs,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _logs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (ctx, i) {
                      final log = _logs[i];
                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getActionColor(log['action']).withValues(alpha: 0.1),
                            child: Icon(_getActionIcon(log['action']), color: _getActionColor(log['action'])),
                          ),
                          title: Text(log['description'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text('Oleh: ${log['user']['name']} • ${log['ip_address'] ?? 'IP Tidak Diketahui'}', style: const TextStyle(fontSize: 12)),
                              Text(DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(log['created_at'])), 
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ),
    );
  }

  Color _getActionColor(String action) {
    if (action.contains('Delete')) return Colors.red;
    if (action.contains('Restock')) return Colors.green;
    return Colors.blue;
  }

  IconData _getActionIcon(String action) {
    if (action.contains('Delete')) return Icons.delete_forever;
    if (action.contains('Restock')) return Icons.add_business;
    return Icons.info_outline;
  }
}
