import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ref_provider.dart';
import '../../authentication/providers/auth_provider.dart';
import '../../groups/providers/group_provider.dart';
import '../../groups/presentation/app_drawer.dart';
import 'ref_detail_screen.dart';
import 'create_ref_screen.dart';
import 'edit_ref_screen.dart';

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

  String _getTitle() {
    final groupProvider = context.watch<GroupProvider>();
    if (groupProvider.selectedGroupId == null) {
      return 'All References';
    } else if (groupProvider.selectedGroupId == 0) {
      return 'Ungrouped';
    } else {
      final group = groupProvider.groups.firstWhere(
        (g) => g.id == groupProvider.selectedGroupId,
        orElse: () => groupProvider.groups.first,
      );
      return group.name;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getTitle()),
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
          Consumer<RefProvider>(
            builder: (context, refProvider, _) {
              if (refProvider.hashtags.isEmpty) {
                return const SizedBox.shrink();
              }

              return Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    FilterChip(
                      label: const Text('All'),
                      selected: refProvider.selectedHashtag == null,
                      onSelected: (_) {
                        refProvider.clearFilter();
                      },
                    ),
                    const SizedBox(width: 8),
                    ...refProvider.hashtags.map((hashtag) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text('#$hashtag'),
                          selected: refProvider.selectedHashtag == hashtag,
                          onSelected: (_) {
                            final groupId =
                                context.read<GroupProvider>().selectedGroupId;
                            refProvider.fetchRefs(
                                hashtag: hashtag, groupId: groupId);
                          },
                        ),
                      );
                    }),
                  ],
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
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
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
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: SelectableText(
                                        ref.title,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge,
                                      ),
                                    ),
                                    PopupMenuButton<String>(
                                      onSelected: (value) async {
                                        if (value == 'edit') {
                                          await _navigateToEdit(ref.id);
                                        } else if (value == 'delete') {
                                          final confirmed =
                                              await showDialog<bool>(
                                            context: context,
                                            builder: (context) => AlertDialog(
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
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.of(context)
                                                          .pop(true),
                                                  style: TextButton.styleFrom(
                                                      foregroundColor:
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
                                              Icon(Icons.edit, size: 20),
                                              SizedBox(width: 8),
                                              Text('Edit'),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(Icons.delete,
                                                  size: 20, color: Colors.red),
                                              SizedBox(width: 8),
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
                                  SelectableText(
                                    ref.summary!,
                                    maxLines: 2,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                  ),
                                ],
                                if (ref.hashtags.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: ref.hashtags.map((hashtag) {
                                      return Text(
                                        '#${hashtag.name}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                            ),
                                      );
                                    }).toList(),
                                  ),
                                ],
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
}
