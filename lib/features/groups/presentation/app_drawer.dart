import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/group_provider.dart';
import '../../../../features/refs/providers/ref_provider.dart';
import '../../../../features/authentication/providers/auth_provider.dart';
import '../../../../shared/models/group.dart';
import '../../../../core/theme/app_theme.dart';
import 'create_group_dialog.dart';
import 'edit_group_dialog.dart';
import 'delete_group_dialog.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  @override
  void initState() {
    super.initState();
    // Drawer가 열릴 때 그룹 트리 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<GroupProvider>().fetchGroupTree();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: Consumer2<GroupProvider, AuthProvider>(
        builder: (context, groupProvider, authProvider, _) {
          return ListView(
            padding: EdgeInsets.zero,
            children: [
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
              ListTile(
                leading: const Icon(Icons.all_inbox),
                title: const Text('All References'),
                selected: groupProvider.selectedGroupId == null,
                onTap: () {
                  groupProvider.selectGroup(null);
                  context.read<RefProvider>().fetchRefs();
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.inbox),
                title: const Text('Ungrouped'),
                selected: groupProvider.selectedGroupId == 0,
                onTap: () {
                  groupProvider.selectGroup(0);
                  context.read<RefProvider>().fetchRefs(groupId: 0);
                  Navigator.pop(context);
                },
              ),
              const Divider(),
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
              if (groupProvider.isLoading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (groupProvider.error != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        'Error loading groups',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.red,
                            ),
                      ),
                      TextButton(
                        onPressed: () => groupProvider.fetchGroupTree(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              else if (groupProvider.groupTree.isEmpty &&
                  groupProvider.groups.isEmpty)
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
                // 그룹 트리 표시
                ...groupProvider.groupTree.isNotEmpty
                    ? _buildGroupTree(
                        context, groupProvider, groupProvider.groupTree, 0)
                    : _buildFlatGroupList(context, groupProvider),
              const Divider(),
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

  List<Widget> _buildGroupTree(
    BuildContext context,
    GroupProvider groupProvider,
    List<Group> groups,
    int depth,
  ) {
    List<Widget> widgets = [];
    for (var group in groups) {
      widgets.add(_buildGroupTile(context, groupProvider, group, depth));
      if (group.children != null && group.children!.isNotEmpty) {
        widgets.addAll(_buildGroupTree(
            context, groupProvider, group.children!, depth + 1));
      }
    }
    return widgets;
  }

  List<Widget> _buildFlatGroupList(
      BuildContext context, GroupProvider groupProvider) {
    return groupProvider.groups.map((group) {
      return _buildGroupTile(context, groupProvider, group, 0);
    }).toList();
  }

  Widget _buildGroupTile(
    BuildContext context,
    GroupProvider groupProvider,
    Group group,
    int depth,
  ) {
    final isSelected = groupProvider.selectedGroupId == group.id;
    final hasChildren = group.childrenCount > 0;

    return ListTile(
      contentPadding: EdgeInsets.only(
        left: 16.0 + (depth * 20.0),
        right: 8,
      ),
      leading: Icon(
        hasChildren ? Icons.folder : Icons.folder_outlined,
        size: 20,
        color: isSelected ? AppTheme.primaryColor : null,
      ),
      title: Text(
        group.name,
        style: TextStyle(
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? AppTheme.primaryColor : null,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (group.refCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryColor.withOpacity(0.1)
                    : Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${group.refCount}',
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected ? AppTheme.primaryColor : null,
                ),
              ),
            ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'addsubgroup') {
                showDialog(
                  context: context,
                  builder: (_) => CreateGroupDialog(parentId: group.id),
                );
              } else if (value == 'edit') {
                showDialog(
                  context: context,
                  builder: (_) => EditGroupDialog(group: group),
                );
              } else if (value == 'delete') {
                // 새로운 삭제 다이얼로그 사용
                final result = await showDialog<bool>(
                  context: context,
                  builder: (_) => DeleteGroupDialog(
                    group: group,
                    hasRefs: group.refCount > 0,
                  ),
                );

                if (result == true) {
                  // 다이얼로그에서 이미 삭제 처리됨
                  // 여기서는 별도 처리 불필요
                }
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'addsubgroup',
                child: Row(
                  children: [
                    Icon(Icons.create_new_folder, size: 18),
                    SizedBox(width: 8),
                    Text('Add Subgroup'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 18),
                    SizedBox(width: 8),
                    Text('Edit'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      selected: isSelected,
      selectedTileColor: AppTheme.primaryColor.withOpacity(0.08),
      onTap: () {
        groupProvider.selectGroup(group.id);
        context.read<RefProvider>().fetchRefs(groupId: group.id);
        Navigator.pop(context);
      },
    );
  }
}
