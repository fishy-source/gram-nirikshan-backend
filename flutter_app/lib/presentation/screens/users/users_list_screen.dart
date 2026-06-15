import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../../data/models/models.dart';

class UsersListScreen extends StatefulWidget {
  const UsersListScreen({super.key});

  @override
  State<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends State<UsersListScreen> {
  final ApiService _api = ApiService();
  List<UserModel> _users = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      final response = await _api.getUsers();
      setState(() {
        _users = (response.data as List).map((u) => UserModel.fromJson(u)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load users: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteUser(UserModel user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Block User'),
        content: Text('Are you sure you want to block/deactivate ${user.name}? They will no longer be able to log in.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Block'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _api.deleteUser(user.id);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User blocked successfully')));
      _loadUsers();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to block user: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Users'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadUsers),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _users.length,
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    final isMe = user.id == currentUser?.id;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: user.isActive ? AppTheme.primaryColor : Colors.grey,
                          child: Text(user.name[0].toUpperCase(), style: const TextStyle(color: Colors.white)),
                        ),
                        title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${user.role} | ${user.mobile}'),
                            if (!user.isActive)
                              const Text('BLOCKED', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                        trailing: isMe
                            ? const Chip(label: Text('You'), backgroundColor: Colors.greenAccent)
                            : IconButton(
                                icon: Icon(user.isActive ? Icons.block : Icons.lock_outline, color: user.isActive ? Colors.red : Colors.grey),
                                tooltip: 'Block User',
                                onPressed: user.isActive ? () => _deleteUser(user) : null,
                              ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.pushNamed(context, '/users/add');
          _loadUsers();
        },
        icon: const Icon(Icons.person_add),
        label: const Text('Add User'),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }
}
