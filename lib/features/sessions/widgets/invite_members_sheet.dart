import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:daddies_app/core/theme/app_colors.dart';
import 'package:daddies_app/core/utils/snackbar_helper.dart';
import 'package:daddies_app/core/utils/haptic_helper.dart';
import 'package:daddies_app/models/user_model.dart';
import 'package:daddies_app/features/sessions/providers/session_provider.dart';
import 'package:daddies_app/services/data_service.dart';

/// Bottom sheet to invite members to a session.
///
/// Shows a searchable list of members with multi-select.
/// Already joined or invited members are excluded.
class InviteMembersSheet extends StatefulWidget {
  final String sessionId;
  final List<String> alreadyInSession;
  final List<String> alreadyInvited;

  const InviteMembersSheet({
    super.key,
    required this.sessionId,
    required this.alreadyInSession,
    required this.alreadyInvited,
  });

  @override
  State<InviteMembersSheet> createState() => _InviteMembersSheetState();
}

class _InviteMembersSheetState extends State<InviteMembersSheet> {
  final _searchController = TextEditingController();
  final Set<String> _selectedIds = {};
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<UserModel> get _filteredMembers {
    final excluded = {
      ...widget.alreadyInSession,
      ...widget.alreadyInvited,
    };
    var members = DataService()
        .users
        .where((u) => !excluded.contains(u.id))
        .toList();

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      members = members.where((u) => u.name.toLowerCase().contains(q)).toList();
    }

    members.sort((a, b) => a.name.compareTo(b.name));
    return members;
  }

  Future<void> _sendInvites() async {
    if (_selectedIds.isEmpty) return;

    final sessionProvider = context.read<SessionProvider>();
    final success = await sessionProvider.invitePlayers(
      widget.sessionId,
      _selectedIds.toList(),
    );

    if (!mounted) return;
    Navigator.of(context).pop();

    if (success) {
      HapticHelper.success();
      SnackbarHelper.showSuccess(
        context,
        'Undangan terkirim ke ${_selectedIds.length} pemain',
      );
    } else {
      SnackbarHelper.showError(context, 'Gagal mengirim undangan');
    }
  }

  @override
  Widget build(BuildContext context) {
    final members = _filteredMembers;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Handle + header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.divider,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Undang Pemain',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.deepCharcoal,
                              ),
                            ),
                          ),
                          if (_selectedIds.isNotEmpty)
                            Text(
                              '${_selectedIds.length} dipilih',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.forestInk,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Search bar
                      TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _searchQuery = v),
                        decoration: InputDecoration(
                          hintText: 'Cari pemain...',
                          hintStyle: const TextStyle(fontSize: 14, color: AppColors.textTertiary),
                          prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textTertiary),
                          filled: true,
                          fillColor: AppColors.surface,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                // Member list
                Expanded(
                  child: members.isEmpty
                      ? const Center(
                          child: Text(
                            'Tidak ada pemain yang bisa diundang',
                            style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: members.length,
                          itemBuilder: (context, index) {
                            final member = members[index];
                            final isSelected = _selectedIds.contains(member.id);
                            final initials = _getInitials(member.name);

                            return ListTile(
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedIds.remove(member.id);
                                  } else {
                                    _selectedIds.add(member.id);
                                  }
                                });
                              },
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected
                                      ? AppColors.forestInk.withValues(alpha: 0.15)
                                      : AppColors.mossAccent.withValues(alpha: 0.12),
                                ),
                                child: Center(
                                  child: isSelected
                                      ? const Icon(Icons.check, size: 20, color: AppColors.forestInk)
                                      : Text(
                                          initials,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.mossAccent,
                                          ),
                                        ),
                                ),
                              ),
                              title: Text(
                                member.name,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: AppColors.deepCharcoal,
                                ),
                              ),
                              subtitle: Text(
                                member.role.name,
                                style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
                              ),
                              trailing: isSelected
                                  ? const Icon(Icons.check_circle, color: AppColors.forestInk, size: 22)
                                  : const Icon(Icons.circle_outlined, color: AppColors.divider, size: 22),
                            );
                          },
                        ),
                ),

                // Send button
                if (_selectedIds.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: AppColors.divider)),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _sendInvites,
                        icon: const Icon(Icons.send, size: 18),
                        label: Text('Kirim Undangan (${_selectedIds.length})'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.forestInk,
                          foregroundColor: AppColors.white,
                          shape: const StadiumBorder(),
                          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '?';
  }
}
