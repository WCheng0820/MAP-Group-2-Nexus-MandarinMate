import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  String _query = '';
  String _roleFilter = 'all';

  static const Color _primary = Color(0xFF6C3BFF);
  static const Color _surface = Color(0xFFF6F3FF);

  @override
  Widget build(BuildContext context) {
    final usersStream =
        (_roleFilter == 'all'
                ? FirebaseFirestore.instance
                      .collection('users')
                      .orderBy('createdAt', descending: true)
                : FirebaseFirestore.instance
                      .collection('users')
                      .where('role', isEqualTo: _roleFilter)
                      .orderBy('createdAt', descending: true))
            .snapshots();

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        title: const Text('Admin Users'),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (value) =>
                        setState(() => _query = value.trim().toLowerCase()),
                    decoration: InputDecoration(
                      hintText: 'Search name or email',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: DropdownButton<String>(
                    value: _roleFilter,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All')),
                      DropdownMenuItem(
                        value: 'student',
                        child: Text('Student'),
                      ),
                      DropdownMenuItem(value: 'tutor', child: Text('Tutor')),
                      DropdownMenuItem(value: 'admin', child: Text('Admin')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _roleFilter = value);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: usersStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: _primary),
                  );
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('Failed to load users.'));
                }

                final docs = snapshot.data?.docs ?? const [];
                final filtered = docs.where((doc) {
                  if (_query.isEmpty) {
                    return true;
                  }
                  final data = doc.data();
                  final name = (data['name'] ?? data['firstName'] ?? '')
                      .toString()
                      .toLowerCase();
                  final email = (data['email'] ?? '').toString().toLowerCase();
                  return name.contains(_query) || email.contains(_query);
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('No users found.'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final doc = filtered[index];
                    final data = doc.data();
                    final name =
                        (data['name'] ?? data['firstName'] ?? 'Unknown')
                            .toString();
                    final email = (data['email'] ?? '').toString();
                    final role = (data['role'] ?? 'student').toString();
                    final level = _toInt(data['level'], fallback: 1);
                    final xp = _extractXp(data);

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: _primary.withValues(alpha: 0.12),
                          child: Text(
                            name.isEmpty ? 'U' : name[0].toUpperCase(),
                            style: const TextStyle(
                              color: _primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        title: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                _ChipLabel(label: role.toUpperCase()),
                                _ChipLabel(label: 'Level $level'),
                                _ChipLabel(label: 'XP $xp'),
                              ],
                            ),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'change_role') {
                              _changeRole(context, doc.id, role);
                            } else if (value == 'delete') {
                              _deleteUser(context, doc.id, name);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'change_role',
                              child: Text('Change role'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete user'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _changeRole(
    BuildContext context,
    String userId,
    String currentRole,
  ) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Change Role',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                for (final role in const ['student', 'tutor', 'admin'])
                  ListTile(
                    title: Text(role.toUpperCase()),
                    trailing: role == currentRole
                        ? const Icon(Icons.check_rounded)
                        : null,
                    onTap: () => Navigator.pop(sheetContext, role),
                  ),
              ],
            ),
          ),
        );
      },
    );

    if (selected == null || selected == currentRole) {
      return;
    }
    if (!mounted) {
      return;
    }

    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'role': selected,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _deleteUser(
    BuildContext context,
    String userId,
    String name,
  ) async {
    final confirm =
        await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Delete User'),
            content: Text('Delete $name? This cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) {
      return;
    }

    await FirebaseFirestore.instance.collection('users').doc(userId).delete();
  }

  int _extractXp(Map<String, dynamic> data) {
    final xp = data['xp'];
    final xpPoints = data['xpPoints'];
    if (xp is num) {
      return xp.toInt();
    }
    if (xpPoints is num) {
      return xpPoints.toInt();
    }
    return 0;
  }

  int _toInt(dynamic value, {required int fallback}) {
    if (value is num) {
      return value.toInt();
    }
    return fallback;
  }
}

class _ChipLabel extends StatelessWidget {
  const _ChipLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF6C3BFF).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF6C3BFF),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
