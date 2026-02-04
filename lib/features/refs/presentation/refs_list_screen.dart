import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ref_provider.dart';
import '../../groups/providers/group_provider.dart';
import '../../groups/presentation/app_drawer.dart';
import 'ref_detail_screen.dart';
import 'ref_form_screen.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import 'dart:async';

class RefsListScreen extends StatefulWidget {
  const RefsListScreen({super.key});

  @override
  State<RefsListScreen> createState() => _RefsListScreenState();
}

class _RefsListScreenState extends State<RefsListScreen> {
  final _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearching = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RefProvider>().fetchRefs();
      context.read<RefProvider>().fetchHashtags();
      context.read<GroupProvider>().fetchGroupTree();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    // 이전 타이머 취소
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    // 새 타이머 시작 (500ms 후 검색 실행)
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.trim().isEmpty) {
        // 빈 문자열이면 검색 초기화 (검색창은 유지)
        final groupId = context.read<GroupProvider>().selectedGroupId;
        final hashtag = context.read<RefProvider>().selectedHashtag;
        context.read<RefProvider>().fetchRefs(
              groupId: groupId,
              hashtag: hashtag,
            );
      } else {
        // 검색 실행
        _performSearch(query);
      }
    });
  }

  Future<void> _refreshRefs() async {
    final groupProvider = context.read<GroupProvider>();
    final refProvider = context.read<RefProvider>();
    final groupId = groupProvider.selectedGroupId;

    await refProvider.fetchRefs(
      groupId: groupId,
      search: refProvider.searchQuery,
      hashtag: refProvider.selectedHashtag,
    );
    await context.read<RefProvider>().fetchHashtags();
    await context.read<GroupProvider>().fetchGroups();
  }

  void _performSearch(String query) {
    final groupId = context.read<GroupProvider>().selectedGroupId;
    final hashtag = context.read<RefProvider>().selectedHashtag;

    context.read<RefProvider>().fetchRefs(
          search: query.trim().isEmpty ? null : query.trim(),
          groupId: groupId,
          hashtag: hashtag,
        );
  }

  void _clearSearch() {
    _searchFocusNode.unfocus();
    _searchController.clear();
    setState(() {
      _isSearching = false;
    });
    final groupId = context.read<GroupProvider>().selectedGroupId;
    final hashtag = context.read<RefProvider>().selectedHashtag;
    context.read<RefProvider>().fetchRefs(
          groupId: groupId,
          hashtag: hashtag,
        );
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
            builder: (_) => RefFormScreen(ref: ref),
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
    if (_isSearching) {
      return TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        autofocus: true,
        style: const TextStyle(color: Colors.black),
        decoration: InputDecoration(
          hintText: 'Search references...',
          border: InputBorder.none,
          hintStyle: TextStyle(color: Colors.grey[400]),
        ),
        onSubmitted: _performSearch,
        onChanged: _onSearchChanged,
      );
    }

    if (groupProvider.selectedGroupId == null) {
      return const Text('All References');
    } else if (groupProvider.selectedGroupId == 0) {
      return const Text('Ungrouped');
    } else {
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
          // 하위 그룹 포함 토글 버튼 추가
          Consumer2<GroupProvider, RefProvider>(
            builder: (context, groupProvider, refProvider, _) {
              // 그룹이 선택되지 않았거나 Ungrouped/All References인 경우 숨김
              if (groupProvider.selectedGroupId == null ||
                  groupProvider.selectedGroupId == 0) {
                return const SizedBox.shrink();
              }

              return IconButton(
                icon: Icon(
                  refProvider.includeSubgroups
                      ? Icons.account_tree
                      : Icons.folder,
                ),
                tooltip: refProvider.includeSubgroups
                    ? 'Including subgroups'
                    : 'Current group only',
                color: refProvider.includeSubgroups
                    ? AppTheme.primaryColor
                    : Colors.grey[600],
                onPressed: () {
                  refProvider.toggleIncludeSubgroups();
                  _refreshRefs();
                },
              );
            },
          ),
          if (_isSearching)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTapDown: (_) {
                  _clearSearch();
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  child: const Icon(Icons.close),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                setState(() {
                  _isSearching = true;
                });
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _searchFocusNode.requestFocus();
                });
              },
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshRefs,
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          // 검색 결과 표시
          Consumer<RefProvider>(
            builder: (context, refProvider, _) {
              if (refProvider.searchQuery != null &&
                  refProvider.searchQuery!.isNotEmpty) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search,
                        size: 16,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Search results for "${refProvider.searchQuery}"',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTapDown: (_) {
                          _clearSearch();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          child: const Icon(Icons.close, size: 18),
                        ),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),

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
                                hashtag: hashtag,
                                groupId: groupId,
                                search: refProvider.searchQuery,
                              );
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
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          refProvider.searchQuery != null
                              ? Icons.search_off
                              : Icons.note_add_outlined,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          refProvider.searchQuery != null
                              ? 'No results found'
                              : 'No references found. Create your first reference!',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _refreshRefs,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: refProvider.refs.length,
                    itemBuilder: (context, index) {
                      final ref = refProvider.refs[index];
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
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            ref.title,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleLarge,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (ref.groupName != null) ...[
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.folder_outlined,
                                                  size: 14,
                                                  color: AppTheme.primaryColor,
                                                ),
                                                const SizedBox(width: 4),
                                                Flexible(
                                                  child: Text(
                                                    ref.groupName!,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color:
                                                          AppTheme.primaryColor,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
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
                                  Linkify(
                                    text: ref.summary!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: AppTheme.textSecondary,
                                          height: 1.4,
                                        ),
                                    linkStyle: TextStyle(
                                      color: AppTheme.primaryColor,
                                      decoration: TextDecoration.underline,
                                    ),
                                    onOpen: (link) async {
                                      final uri = Uri.parse(link.url);
                                      if (!await launchUrl(uri,
                                          mode:
                                              LaunchMode.externalApplication)) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                                content: Text(
                                                    'Could not open ${link.url}')),
                                          );
                                        }
                                      }
                                    },
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
              builder: (_) => const RefFormScreen(),
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
