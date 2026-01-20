import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ref_provider.dart';
import '../../groups/providers/group_provider.dart';
import '../../groups/presentation/app_drawer.dart';
import 'ref_detail_screen.dart';
import 'create_ref_screen.dart';
import 'edit_ref_screen.dart';
import '../../../core/theme/app_theme.dart';

class RefsListScreen extends StatefulWidget {
  const RefsListScreen({super.key});

  @override
  State<RefsListScreen> createState() => _RefsListScreenState();
}

class _RefsListScreenState extends State<RefsListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RefProvider>().fetchRefs();
      context.read<RefProvider>().fetchHashtags();
      context.read<GroupProvider>().fetchGroups();
    });
  }

  Future<void> _refreshRefs() async {
    final groupProvider = context.read<GroupProvider>();
    final groupId = groupProvider.selectedGroupId;

    await context.read<RefProvider>().fetchRefs(groupId: groupId);
    await context.read<RefProvider>().fetchHashtags();
    await context.read<GroupProvider>().fetchGroups();
  }

  Future<void> _navigateToEdit(int refId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    final ref = await context.read<RefProvider>().fetchRef(refId);

    if (mounted) {
      Navigator.of(context).pop();

      if (ref != null) {
        final result = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => EditRefScreen(ref: ref),
          ),
        );

        if (result == true) {
          _refreshRefs();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load reference details')),
        );
      }
    }
  }

  Widget _buildTitle(GroupProvider groupProvider) {
    if (groupProvider.selectedGroupId == null) {
      return const Text('All References');
    } else if (groupProvider.selectedGroupId == 0) {
      return const Text('Ungrouped');
    } else {
      // Breadcrumb 표시
      if (groupProvider.breadcrumbs.isNotEmpty) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (int i = 0; i < groupProvider.breadcrumbs.length; i++) ...[
                if (i > 0)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(Icons.chevron_right, size: 16),
                  ),
                Text(
                  groupProvider.breadcrumbs[i]['name'] as String,
                  style: TextStyle(
                    fontWeight: i == groupProvider.breadcrumbs.length - 1
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ],
            ],
          ),
        );
      }

      final group = groupProvider.groups.firstWhere(
        (g) => g.id == groupProvider.selectedGroupId,
        orElse: () => groupProvider.groups.first,
      );
      return Text(group.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Consumer<GroupProvider>(
          builder: (context, groupProvider, _) => _buildTitle(groupProvider),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshRefs,
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          // 해시태그 필터
          // 해시태그 필터
          Consumer<RefProvider>(
            builder: (context, refProvider, _) {
              if (refProvider.hashtags.isEmpty) {
                return const SizedBox.shrink();
              }

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(color: AppTheme.dividerColor),
                  ),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('All'),
                        selected: refProvider.selectedHashtag == null,
                        onSelected: (_) {
                          refProvider.clearFilter();
                        },
                        backgroundColor: Colors.grey[100],
                        selectedColor: AppTheme.primaryColor.withOpacity(0.15),
                        checkmarkColor: AppTheme.primaryColor,
                        labelStyle: TextStyle(
                          color: refProvider.selectedHashtag == null
                              ? AppTheme.primaryColor
                              : AppTheme.textSecondary,
                          fontWeight: refProvider.selectedHashtag == null
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                        side: BorderSide(
                          color: refProvider.selectedHashtag == null
                              ? AppTheme.primaryColor
                              : AppTheme.borderColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ...refProvider.hashtags.map((hashtag) {
                        final isSelected =
                            refProvider.selectedHashtag == hashtag;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text('#$hashtag'),
                            selected: isSelected,
                            onSelected: (_) {
                              final groupId =
                                  context.read<GroupProvider>().selectedGroupId;
                              refProvider.fetchRefs(
                                  hashtag: hashtag, groupId: groupId);
                            },
                            backgroundColor: Colors.grey[100],
                            selectedColor:
                                AppTheme.primaryColor.withOpacity(0.15),
                            checkmarkColor: AppTheme.primaryColor,
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? AppTheme.primaryColor
                                  : AppTheme.textSecondary,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                            side: BorderSide(
                              color: isSelected
                                  ? AppTheme.primaryColor
                                  : AppTheme.borderColor,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              );
            },
          ),

          const Divider(height: 1),
          // 레퍼런스 목록
          Expanded(
            child: Consumer<RefProvider>(
              builder: (context, refProvider, _) {
                if (refProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (refProvider.error != null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Error: ${refProvider.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _refreshRefs,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                if (refProvider.refs.isEmpty) {
                  return const Center(
                    child: Text(
                        'No references found. Create your first reference!'),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _refreshRefs,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: refProvider.refs.length,
                    itemBuilder: (context, index) {
                      final ref = refProvider.refs[index];
                      // itemBuilder 내부의 Card 부분
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.borderColor),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: InkWell(
                          onTap: () async {
                            final result =
                                await Navigator.of(context).push<bool>(
                              MaterialPageRoute(
                                builder: (_) => RefDetailScreen(refId: ref.id),
                              ),
                            );

                            if (result == true) {
                              _refreshRefs();
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        ref.title,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    PopupMenuButton<String>(
                                      icon: Icon(Icons.more_vert,
                                          color: Colors.grey[600]),
                                      onSelected: (value) async {
                                        if (value == 'edit') {
                                          await _navigateToEdit(ref.id);
                                        } else if (value == 'delete') {
                                          final confirmed =
                                              await showDialog<bool>(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          16)),
                                              title: const Text(
                                                  'Delete Reference'),
                                              content: const Text(
                                                  'Are you sure you want to delete this reference?'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.of(context)
                                                          .pop(false),
                                                  child: const Text('Cancel'),
                                                ),
                                                FilledButton(
                                                  onPressed: () =>
                                                      Navigator.of(context)
                                                          .pop(true),
                                                  style: FilledButton.styleFrom(
                                                      backgroundColor:
                                                          Colors.red),
                                                  child: const Text('Delete'),
                                                ),
                                              ],
                                            ),
                                          );

                                          if (confirmed == true && mounted) {
                                            await refProvider.deleteRef(ref.id);
                                          }
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(
                                          value: 'edit',
                                          child: Row(
                                            children: [
                                              Icon(Icons.edit_outlined,
                                                  size: 18),
                                              SizedBox(width: 12),
                                              Text('Edit'),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(Icons.delete_outline,
                                                  size: 18, color: Colors.red),
                                              SizedBox(width: 12),
                                              Text('Delete',
                                                  style: TextStyle(
                                                      color: Colors.red)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                if (ref.summary != null &&
                                    ref.summary!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    ref.summary!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: AppTheme.textSecondary,
                                          height: 1.4,
                                        ),
                                  ),
                                ],
                                if (ref.hashtags.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children:
                                        ref.hashtags.take(3).map((hashtag) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryColor
                                              .withOpacity(0.08),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: AppTheme.primaryColor
                                                .withOpacity(0.2),
                                          ),
                                        ),
                                        child: Text(
                                          '#${hashtag.name}',
                                          style: TextStyle(
                                            color: AppTheme.primaryColor,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.access_time,
                                        size: 12, color: Colors.grey[400]),
                                    const SizedBox(width: 4),
                                    Text(
                                      _formatDate(ref.updatedAt),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Colors.grey[500],
                                            fontSize: 11,
                                          ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => const CreateRefScreen(),
            ),
          );

          if (result == true) {
            _refreshRefs();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  // _formatDate 함수를 여기에 추가 (build 메서드 아래)
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
  }
}
