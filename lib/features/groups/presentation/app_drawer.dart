import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/group_provider.dart';
import '../../../features/papers/providers/paper_provider.dart';
import '../../../features/authentication/providers/auth_provider.dart';
import 'create_group_dialog.dart';
import 'edit_group_dialog.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Consumer2<GroupProvider, AuthProvider>(
        builder: (context, groupProvider, authProvider, _) {
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              // 헤더
              DrawerHeader(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Paperef',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      authProvider.user?.email ?? '',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white70,
                          ),
                    ),
                  ],
                ),
              ),

              // 전체 메모
              ListTile(
                leading: const Icon(Icons.all_inbox),
                title: const Text('All Papers'),
                selected: groupProvider.selectedGroupId == null,
                onTap: () {
                  groupProvider.selectGroup(null);
                  context.read<PaperProvider>().fetchPapers();
                  Navigator.pop(context);
                },
              ),

              // 그룹 없는 메모
              ListTile(
                leading: const Icon(Icons.inbox),
                title: const Text('Ungrouped'),
                selected: groupProvider.selectedGroupId == 0,
                onTap: () {
                  groupProvider.selectGroup(0);
                  context.read<PaperProvider>().fetchPapers(groupId: 0);
                  Navigator.pop(context);
                },
              ),

              const Divider(),

              // 그룹 헤더
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Groups',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, size: 20),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => const CreateGroupDialog(),
                        );
                      },
                      tooltip: 'Add Group',
                    ),
                  ],
                ),
              ),

              // 그룹 목록
              if (groupProvider.isLoading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (groupProvider.groups.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No groups yet',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                ...groupProvider.groups.map((group) {
                  return ListTile(
                    leading: const Icon(Icons.folder),
                    title: Text(group.name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${group.paperCount}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'edit') {
                              showDialog(
                                context: context,
                                builder: (_) => EditGroupDialog(group: group),
                              );
                            } else if (value == 'delete') {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete Group'),
                                  content: Text(
                                    'Are you sure you want to delete "${group.name}"? Papers in this group will not be deleted.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(true),
                                      style: TextButton.styleFrom(
                                          foregroundColor: Colors.red),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );

                              if (confirmed == true) {
                                await groupProvider.deleteGroup(group.id);
                              }
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Edit'),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete',
                                  style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    selected: groupProvider.selectedGroupId == group.id,
                    onTap: () {
                      groupProvider.selectGroup(group.id);
                      context
                          .read<PaperProvider>()
                          .fetchPapers(groupId: group.id);
                      Navigator.pop(context);
                    },
                  );
                }),

              const Divider(),

              // 로그아웃
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Logout'),
                onTap: () async {
                  await context.read<AuthProvider>().logout();
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
