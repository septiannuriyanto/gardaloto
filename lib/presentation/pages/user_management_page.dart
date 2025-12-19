import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gardaloto/core/service_locator.dart';
import 'package:gardaloto/domain/entities/user_entity.dart';
import 'package:gardaloto/presentation/cubit/manpower_cubit.dart';
import 'package:gardaloto/presentation/widget/app_background.dart';
import 'package:gardaloto/presentation/widget/glass_panel.dart';
import 'package:go_router/go_router.dart';


class UserManagementPage extends StatelessWidget {
  const UserManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => sl<ManpowerCubit>()..fetchAllUsers(),
      child: const UserManagementView(),
    );
  }
}

class UserManagementView extends StatelessWidget {
  const UserManagementView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'User Management',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              if (value == 'add_nrp') {
                _showAddNrpDialog(context);
              }
            },
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: 'add_nrp',
                    child: Text('Add New NRP'),
                  ),
                ],
          ),
        ],
      ),
      body: AppBackground(
        child: BlocConsumer<ManpowerCubit, ManpowerState>(
          listener: (context, state) {
            if (state is ManpowerError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          builder: (context, state) {
            if (state is ManpowerSyncing) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.cyanAccent),
              );
            }
            if (state is ManpowerLoaded) {
              final users = state.users;
              if (users.isEmpty) {
                return const Center(
                  child: Text(
                    "No users found",
                    style: TextStyle(color: Colors.white),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildUserCard(context, user),
                  );
                },
              );
            }
            return const Center(
              child: CircularProgressIndicator(color: Colors.cyanAccent),
            );
          },
        ),
      ),
    );
  }

  void _showAddNrpDialog(BuildContext context) {
    final controller = TextEditingController();
    // Capture the cubit from the parent context where it is available
    final cubit = context.read<ManpowerCubit>();

    showDialog(
      context: context,
      builder:
          (dialogContext) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(24),
            child: GlassPanel(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    "Add New NRP",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "NRP",
                      labelStyle: const TextStyle(color: Colors.white70),
                      hintText: "Enter NRP to allow registration",
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.cyanAccent),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text(
                          "Cancel",
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          final nrp = controller.text.trim();
                          if (nrp.isNotEmpty) {
                            cubit.addNewUser(nrp);
                            Navigator.pop(dialogContext);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.cyanAccent.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text("Add"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildUserCard(BuildContext context, UserEntity user) {
    bool isNew = false;
    if (user.active == false && user.updatedAt != null) {
      final diff = DateTime.now().difference(user.updatedAt!);
      if (diff.inDays <= 30) {
        isNew = true;
      }
    }
    if (user.active == false && user.updatedAt == null) isNew = true;

    return GlassPanel(
      onTap: () {
        context.push('/user-management/modify-user', extra: {
          'user': user,
          'cubit': context.read<ManpowerCubit>(),
        });
      },
      padding: const EdgeInsets.all(16),
      border: user.active == false ? Border.all(color: Colors.amber, width: 2) : null,
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.white24,
            backgroundImage: user.photoUrl != null && user.photoUrl!.isNotEmpty
                ? NetworkImage(user.photoUrl!)
                : null,
            child: (user.photoUrl == null || user.photoUrl!.isEmpty)
                ? const Icon(Icons.person, color: Colors.white)
                : null,
          ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        user.nama ?? 'No Name',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (isNew) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            "NEW",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    user.nrp ?? 'No NRP',
                    style: TextStyle(
                      color: Colors.cyanAccent.shade100,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    user.positionDescription ?? 'Unknown Position',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),

            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white70),
              onSelected: (value) {
                if (value == 'modify') {
                  context.push('/user-management/modify-user', extra: {
                    'user': user,
                    'cubit': context.read<ManpowerCubit>(),
                  });
                } else if (value == 'deactivate') {
                  _confirmAction(
                    context: context,
                    title: "Deactivate User",
                    content:
                        "Are you sure you want to deactivate ${user.nama}?",
                    onConfirm:
                        () => context.read<ManpowerCubit>().toggleUserStatus(
                          user.nrp!,
                          false,
                        ),
                  );
                } else if (value == 'activate') {
                  context.read<ManpowerCubit>().toggleUserStatus(
                    user.nrp!,
                    true,
                  );
                } else if (value == 'unregister') {
                  _confirmAction(
                    context: context,
                    title: "Unregister User",
                    content:
                        "This will remove ${user.nama} from the registered list. Continue?",
                    onConfirm:
                        () => context.read<ManpowerCubit>().unregisterUser(
                          user.nrp!,
                        ),
                  );
                } else if (value == 'delete') {
                  _confirmAction(
                    context: context,
                    title: "Delete User",
                    content:
                        "This is IRREVERSIBLE. Are you sure you want to delete ${user.nama}?",
                    onConfirm:
                        () =>
                            context.read<ManpowerCubit>().deleteUser(user.nrp!),
                  );
                }
              },
              itemBuilder:
                  (context) => [
                    const PopupMenuItem(
                      value: 'modify',
                      child: Text("Modify User"),
                    ),
                    if (user.active == true)
                      const PopupMenuItem(
                        value: 'deactivate',
                        child: Text("Deactivate"),
                      ),

                    // Activate is handled by Modify Page, but kept logic here just in case or we removed it?
                    // User said "remove activate button" from row.
                    // So I won't show 'activate' here.
                    const PopupMenuItem(
                      value: 'unregister',
                      child: Text(
                        "Unregister",
                        style: TextStyle(color: Colors.orange),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        "Delete User",
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
            ),
          ],
        ),
      );
  }

  void _confirmAction({
    required BuildContext context,
    required String title,
    required String content,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  onConfirm();
                },
                child: const Text(
                  "Confirm",
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }
}
