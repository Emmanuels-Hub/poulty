import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/enums.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/enum_labels.dart';
import '../../data/models/user_model.dart';
import '../../modules/auth/auth_controller.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  final auth = Get.find<AuthController>();

  @override
  Widget build(BuildContext context) {
    final users = auth.users;
    final adminCount = users.where((u) => u.role == UserRole.admin).length;

    return Scaffold(
      appBar: AppBar(title: const Text('User Management')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showUserDialog(),
        child: const Icon(Icons.person_add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Administrators: $adminCount / ${AppConstants.maxAdmins}',
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(user.displayName[0].toUpperCase()),
                    ),
                    title: Text(user.displayName),
                    subtitle: Text(
                      '@${user.username} · ${EnumLabels.userRole(user.role)}',
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'edit') _showUserDialog(user: user);
                        if (value == 'delete') _confirmDelete(user);
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'edit', child: Text('Edit')),
                        const PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showUserDialog({UserModel? user}) async {
    final isEdit = user != null;
    final usernameController = TextEditingController(text: user?.username ?? '');
    final nameController = TextEditingController(text: user?.displayName ?? '');
    final passwordController = TextEditingController();
    var role = user?.role ?? UserRole.viewer;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit User' : 'Add User'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: usernameController,
                  enabled: !isEdit,
                  decoration: const InputDecoration(labelText: 'Username'),
                ),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Display Name'),
                ),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: isEdit ? 'New Password (optional)' : 'Password',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<UserRole>(
                  value: role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: UserRole.values
                      .map(
                        (r) => DropdownMenuItem(
                          value: r,
                          child: Text(EnumLabels.userRole(r)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setDialogState(() => role = v ?? role),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                String? error;
                if (isEdit) {
                  error = await auth.updateUser(
                    user.copyWith(
                      displayName: nameController.text.trim(),
                      role: role,
                    ),
                    newPassword: passwordController.text.isEmpty
                        ? null
                        : passwordController.text,
                  );
                } else {
                  error = await auth.createUser(
                    username: usernameController.text.trim(),
                    displayName: nameController.text.trim(),
                    password: passwordController.text,
                    roleName: role.name,
                  );
                }

                if (!context.mounted) return;
                if (error != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(error)),
                  );
                } else {
                  Navigator.pop(ctx);
                  setState(() {});
                }
              },
              child: Text(isEdit ? 'Save' : 'Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(UserModel user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Remove ${user.displayName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.criticalRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final error = await auth.deleteUser(user.id);
      if (error != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      }
      setState(() {});
    }
  }
}
