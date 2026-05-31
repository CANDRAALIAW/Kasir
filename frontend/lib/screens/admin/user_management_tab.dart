import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class UserManagementTab extends StatefulWidget {
  const UserManagementTab({super.key});

  @override
  State<UserManagementTab> createState() => _UserManagementTabState();
}

class _UserManagementTabState extends State<UserManagementTab> {
  final ApiService _apiService = ApiService();
  List<dynamic> _cashiers = [];
  List<Map<String, dynamic>> _branches = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    await Future.wait([_fetchCashiers(), _fetchBranches()]);
    if (mounted) setState(() => _isLoading = false);
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

  Future<void> _fetchCashiers() async {
    try {
      final response = await _apiService.get('/users');
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _cashiers = jsonDecode(response.body);
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching cashiers: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengambil data kasir: $e')),
        );
      }
    }
  }

  Future<void> _deleteCashier(int id) async {
    try {
      final response = await _apiService.delete('/users/$id');
      if (response.statusCode == 200) {
        _fetchCashiers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kasir berhasil dihapus'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Delete cashier error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menghapus kasir: $e')),
        );
      }
    }
  }

  void _showAddEditDialog({Map<String, dynamic>? cashier}) {
    final isEditing = cashier != null;
    final nameController = TextEditingController(text: cashier?['name'] ?? '');
    final emailController = TextEditingController(text: cashier?['email'] ?? '');
    final passwordController = TextEditingController();
    int selectedBranchId = cashier?['branch_id'] ?? (_branches.isNotEmpty ? _branches.first['id'] : 1);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            isEditing ? 'Edit Info Kasir' : 'Tambah Kasir Baru',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Nama Lengkap',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Alamat Email',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: isEditing ? 'Password Baru (Opsional)' : 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                _branches.isEmpty
                    ? const Center(child: Text('Memuat cabang...'))
                    : DropdownButtonFormField<int>(
                        initialValue: _branches.any((b) => b['id'] == selectedBranchId)
                            ? selectedBranchId
                            : _branches.first['id'],
                        decoration: InputDecoration(
                          labelText: 'Cabang Penugasan',
                          prefixIcon: const Icon(Icons.storefront),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: _branches.map((branch) => DropdownMenuItem<int>(
                          value: branch['id'],
                          child: Text(branch['name'] ?? 'Cabang ${branch['id']}'),
                        )).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedBranchId = val);
                          }
                        },
                      ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () async {
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                if (nameController.text.isEmpty ||
                    emailController.text.isEmpty ||
                    (!isEditing && passwordController.text.isEmpty)) {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(content: Text('Harap isi semua kolom wajib')),
                  );
                  return;
                }

                final body = {
                  'name': nameController.text,
                  'email': emailController.text,
                  'branch_id': selectedBranchId,
                  if (passwordController.text.isNotEmpty) 'password': passwordController.text,
                };

                try {
                  final response = isEditing
                      ? await _apiService.put('/users/${cashier['id']}', body)
                      : await _apiService.post('/users', body);

                  if (response.statusCode == 200 || response.statusCode == 201) {
                    if (mounted) {
                      Navigator.of(context).pop();
                      _fetchCashiers();
                      scaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: Text(isEditing
                              ? 'Info kasir diperbarui'
                              : 'Kasir baru berhasil didaftarkan'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(content: Text('Gagal menyimpan data: $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.pink),
              child: const Text('Simpan', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(Map<String, dynamic> cashier) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Kasir?'),
        content: Text('Apakah Anda yakin ingin menghapus akun kasir ${cashier['name']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteCashier(cashier['id']);
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
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
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _cashiers.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _fetchData,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: _cashiers.length,
                        itemBuilder: (ctx, i) {
                          final cashier = _cashiers[i];
                          final branchName = cashier['branch'] != null
                              ? cashier['branch']['name']
                              : 'Cabang ${cashier['branch_id']}';

                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(color: Colors.pink.shade50),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              leading: CircleAvatar(
                                backgroundColor: Colors.pink.shade50,
                                child: const Icon(Icons.person, color: Colors.pink),
                              ),
                              title: Text(
                                cashier['name'] ?? '',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(cashier['email'] ?? ''),
                                  const SizedBox(height: 2),
                                  Text(
                                    branchName,
                                    style: TextStyle(
                                      color: Colors.pink.shade700,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined,
                                        color: Colors.blue),
                                    onPressed: () =>
                                        _showAddEditDialog(cashier: cashier),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        color: Colors.red),
                                    onPressed: () =>
                                        _showDeleteConfirmation(cashier),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.pink,
        onPressed: () => _showAddEditDialog(),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Tambah Kasir', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 80, color: Colors.pink.shade100),
          const SizedBox(height: 16),
          Text(
            'Belum ada kasir terdaftar',
            style: TextStyle(color: Colors.pink.shade300, fontSize: 18),
          ),
        ],
      ),
    );
  }
}
