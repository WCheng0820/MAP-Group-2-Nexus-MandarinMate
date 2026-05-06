import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mandarinmate/models/user_model.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  String _query = '';
  String _roleFilter = 'all';
  String _statusFilter = 'all';
  final Set<String> _busyUserIds = <String>{};

  static const Color _primary = Color(0xFF6C3BFF);
  static const Color _surface = Color(0xFFF6F3FF);

  @override
  Widget build(BuildContext context) {
    final usersStream = FirebaseFirestore.instance
        .collection('users')
        .orderBy('createdAt', descending: true)
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
            child: Column(
              children: [
                TextField(
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
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: DropdownButton<String>(
                          value: _roleFilter,
                          isExpanded: true,
                          underline: const SizedBox.shrink(),
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('All')),
                            DropdownMenuItem(
                              value: 'student',
                              child: Text('Student'),
                            ),
                            DropdownMenuItem(
                              value: 'tutor',
                              child: Text('Tutor'),
                            ),
                            DropdownMenuItem(
                              value: 'admin',
                              child: Text('Admin'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _roleFilter = value);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: DropdownButton<String>(
                          value: _statusFilter,
                          isExpanded: true,
                          underline: const SizedBox.shrink(),
                          items: const [
                            DropdownMenuItem(
                              value: 'all',
                              child: Text('All Status'),
                            ),
                            DropdownMenuItem(
                              value: 'pending',
                              child: Text('Pending'),
                            ),
                            DropdownMenuItem(
                              value: 'approved',
                              child: Text('Approved'),
                            ),
                            DropdownMenuItem(
                              value: 'rejected',
                              child: Text('Rejected'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _statusFilter = value);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
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
                  final data = doc.data();
                  final isArchived = data['isArchived'] == true;
                  if (isArchived) {
                    return false;
                  }
                  final role = (data['role'] ?? 'student')
                      .toString()
                      .toLowerCase();
                  final status = _membershipStatusFromData(data).name;

                  if (_roleFilter != 'all' && role != _roleFilter) {
                    return false;
                  }
                  if (_statusFilter != 'all' && status != _statusFilter) {
                    return false;
                  }
                  if (_query.isEmpty) {
                    return true;
                  }
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
                    final membershipStatus = _membershipStatusFromData(data);
                    final level = _toInt(data['level'], fallback: 1);
                    final xp = _extractXp(data);
                    final isBusy = _busyUserIds.contains(doc.id);
                    final isCurrentUser =
                        FirebaseAuth.instance.currentUser?.uid == doc.id;

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
                                _StatusChip(status: membershipStatus),
                                _ChipLabel(label: 'Level $level'),
                                _ChipLabel(label: 'XP $xp'),
                              ],
                            ),
                          ],
                        ),
                        trailing: isBusy
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: _primary,
                                ),
                              )
                            : PopupMenuButton<String>(
                                onSelected: (value) => _handleUserAction(
                                  action: value,
                                  userId: doc.id,
                                  userName: name,
                                  currentRole: role,
                                ),
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                    value: 'change_role',
                                    child: Text('Change role'),
                                  ),
                                  if (membershipStatus !=
                                      MembershipStatus.approved)
                                    const PopupMenuItem(
                                      value: 'approve',
                                      child: Text('Approve member'),
                                    ),
                                  if (membershipStatus !=
                                      MembershipStatus.rejected)
                                    const PopupMenuItem(
                                      value: 'reject',
                                      child: Text('Reject member'),
                                    ),
                                  if (!isCurrentUser)
                                    const PopupMenuItem(
                                      value: 'remove_from_list',
                                      child: Text('Remove from list'),
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

  Future<bool> _changeRole(
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
      return false;
    }
    if (!mounted) {
      return false;
    }

    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'role': selected,
      'updatedAt': DateTime.now().toIso8601String(),
    });
    return true;
  }

  Future<void> _updateMembershipStatus({
    required String userId,
    required MembershipStatus status,
  }) async {
    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'membershipStatus': status.name,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _handleUserAction({
    required String action,
    required String userId,
    required String userName,
    required String currentRole,
  }) async {
    if (_busyUserIds.contains(userId) || !mounted) {
      return;
    }

    setState(() => _busyUserIds.add(userId));
    try {
      switch (action) {
        case 'change_role':
          final changed = await _changeRole(context, userId, currentRole);
          if (!mounted) {
            return;
          }
          if (changed) {
            _showMessage(context, 'Role updated for $userName.');
          }
          break;
        case 'approve':
          await _updateMembershipStatus(
            userId: userId,
            status: MembershipStatus.approved,
          );
          if (!mounted) {
            return;
          }
          _showMessage(context, '$userName has been approved.');
          break;
        case 'reject':
          await _updateMembershipStatus(
            userId: userId,
            status: MembershipStatus.rejected,
          );
          if (!mounted) {
            return;
          }
          _showMessage(context, '$userName has been rejected.');
          break;
        case 'remove_from_list':
          final confirmed = await _confirmArchiveUser(context, userName);
          if (!mounted || !confirmed) {
            return;
          }
          await _archiveUser(userId: userId);
          if (!mounted) {
            return;
          }
          _showMessage(context, '$userName was removed from the list.');
          break;
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      _showMessage(context, 'Action failed: $e');
    } finally {
      if (mounted) {
        setState(() => _busyUserIds.remove(userId));
      }
    }
  }

  Future<bool> _confirmArchiveUser(
    BuildContext context,
    String userName,
  ) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Remove From List'),
            content: Text(
              'Hide $userName from Manage Users? This will not delete the login account.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Remove'),
              ),
            ],
          ),
        ) ??
        false;
    return confirmed;
  }

  Future<void> _archiveUser({required String userId}) async {
    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'isArchived': true,
      'archivedAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
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

  MembershipStatus _membershipStatusFromData(Map<String, dynamic> data) {
    final status = (data['membershipStatus'] ?? 'approved')
        .toString()
        .toLowerCase()
        .split('.')
        .last;
    switch (status) {
      case 'pending':
        return MembershipStatus.pending;
      case 'rejected':
        return MembershipStatus.rejected;
      case 'approved':
      default:
        return MembershipStatus.approved;
    }
  }

  void _showMessage(BuildContext context, String message) {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final MembershipStatus status;

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final Color color;
    switch (status) {
      case MembershipStatus.approved:
        label = 'APPROVED';
        color = const Color(0xFF15803D);
        break;
      case MembershipStatus.rejected:
        label = 'REJECTED';
        color = const Color(0xFFB91C1C);
        break;
      case MembershipStatus.pending:
        label = 'PENDING';
        color = const Color(0xFFB45309);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
