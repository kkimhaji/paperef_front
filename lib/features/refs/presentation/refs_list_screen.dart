import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ref_provider.dart';
import '../../groups/providers/group_provider.dart';
import '../../groups/presentation/app_drawer.dart';
import 'ref_detail_screen.dart';
import 'ref_form_screen.dart';
import '../../../core/theme/app_theme.dart';
import 'dart:async';

class RefsListScreen extends StatefulWidget {
  const RefsListScreen({super.key});

  @override
  State<RefsListScreen> createState() => _RefsListScreenState();
}

class _RefsListScreenState extends State<RefsListScreen> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  bool _isSearching = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshRefs();
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
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  void _performSearch(String query) {
    final groupId = context.read<GroupProvider>().selectedGroupId;
    final hashtag = context.read<RefProvider>().selectedHashtag;
    final includeSubgroups = context.read<RefProvider>().includeSubgroups;

    context.read<RefProvider>().fetchRefs(
          search: query.trim().isEmpty ? null : query.trim(),
          groupId: groupId,
          hashtag: hashtag,
          includeSubgroups: includeSubgroups,
        );
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _isSearching = false;
    });
    final groupId = context.read<GroupProvider>().selectedGroupId;
    final hashtag = context.read<RefProvider>().selectedHashtag;
    final includeSubgroups = context.read<RefProvider>().includeSubgroups;

    context.read<RefProvider>().fetchRefs(
          groupId: groupId,
          hashtag: hashtag,
          includeSubgroups: includeSubgroups,
        );
  }

  Future<void> _refreshRefs() async {
    final groupId = context.read<GroupProvider>().selectedGroupId;
    final includeSubgroups = context.read<RefProvider>().includeSubgroups;

    await context.read<RefProvider>().fetchRefs(
          groupId: groupId,
          search: context.read<RefProvider>().searchQuery,
          hashtag: context.read<RefProvider>().selectedHashtag,
          includeSubgroups: includeSubgroups,
        );
    await context.read<RefProvider>().fetchHashtags();
    await context.read<GroupProvider>().fetchGroupTree();
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

  /// 클릭 가능한 Breadcrumb 타이틀 생성
  Widget _buildBreadcrumbTitle(GroupProvider groupProvider) {
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

    // All References
    if (groupProvider.selectedGroupId == null) {
      return const Text('All References');
    }

    // Ungrouped
    if (groupProvider.selectedGroupId == 0) {
      return const Text('Ungrouped');
    }

    // 그룹이 선택된 경우: 클릭 가능한 breadcrumb
    if (groupProvider.breadcrumbs.isNotEmpty) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (int i = 0; i < groupProvider.breadcrumbs.length; i++) ...[
              // 구분자 (첫 번째 항목 제외)
              if (i > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                ),

              // 클릭 가능한 그룹명
              InkWell(
                onTap: () {
                  final groupId = groupProvider.breadcrumbs[i]['id'] as int;

                  // 현재 선택된 그룹과 다른 경우에만 이동
                  if (groupId != groupProvider.selectedGroupId) {
                    groupProvider.selectGroup(groupId);
                    final includeSubgroups =
                        context.read<RefProvider>().includeSubgroups;
                    context.read<RefProvider>().fetchRefs(
                          groupId: groupId,
                          includeSubgroups: includeSubgroups,
                        );
                  }
                },
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    groupProvider.breadcrumbs[i]['name'] as String,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: i == groupProvider.breadcrumbs.length - 1
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: i == groupProvider.breadcrumbs.length - 1
                          ? Colors.black
                          : AppTheme.primaryColor,
                      decoration: i == groupProvider.breadcrumbs.length - 1
                          ? TextDecoration.none
                          : TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    // Fallback: 단일 그룹명
    final group = groupProvider.groups.firstWhere(
      (g) => g.id == groupProvider.selectedGroupId,
      orElse: () => groupProvider.groups.first,
    );
    return Text(group.name);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Consumer<GroupProvider>(
          builder: (context, groupProvider, _) {
            return _buildBreadcrumbTitle(groupProvider);
          },
        ),
        actions: [
          // 하위 그룹 포함/비포함 토글 버튼 (그룹 선택 시에만 표시)
          Consumer2<GroupProvider, RefProvider>(
            builder: (context, groupProvider, refProvider, _) {
              // 그룹이 선택되고, Ungrouped가 아닌 경우에만 표시
              if (groupProvider.selectedGroupId != null &&
                  groupProvider.selectedGroupId != 0) {
                return IconButton(
                  icon: Icon(
                    refProvider.includeSubgroups
                        ? Icons.account_tree // 트리 아이콘 (하위 포함)
                        : Icons.folder, // 폴더 아이콘 (현재만)
                  ),
                  tooltip: refProvider.includeSubgroups
                      ? 'Include subgroups'
                      : 'Current group only',
                  color: refProvider.includeSubgroups
                      ? AppTheme.primaryColor
                      : Colors.grey[600],
                  onPressed: () {
                    refProvider.toggleIncludeSubgroups();
                    refProvider.fetchRefs(
                      groupId: groupProvider.selectedGroupId,
                      search: refProvider.searchQuery,
                      hashtag: refProvider.selectedHashtag,
                      includeSubgroups: refProvider.includeSubgroups,
                    );
                  },
                );
              }
              return const SizedBox.shrink();
            },
          ),

          if (_isSearching)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTapDown: (_) => _clearSearch(),
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
          // 검색 필터 표시
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
                          'Searching: "${refProvider.searchQuery}"',
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          size: 18,
                          color: AppTheme.primaryColor,
                        ),
                        onPressed: () {
                          refProvider.clearSearch();
                        },
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
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(color: AppTheme.dividerColor),
                  ),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: refProvider.hashtags.map((hashtag) {
                      final isSelected = refProvider.selectedHashtag == hashtag;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text('#$hashtag'),
                          selected: isSelected,
                          onSelected: (_) {
                            final groupId =
                                context.read<GroupProvider>().selectedGroupId;
                            final includeSubgroups =
                                refProvider.includeSubgroups;

                            refProvider.fetchRefs(
                              hashtag: hashtag,
                              groupId: groupId,
                              search: refProvider.searchQuery,
                              includeSubgroups: includeSubgroups,
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
                    }).toList(),
                  ),
                ),
              );
            },
          ),

          // 레퍼런스 리스트
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
                        Icon(Icons.error_outline,
                            size: 48, color: Colors.red[300]),
                        const SizedBox(height: 16),
                        Text(
                          'Error: ${refProvider.error}',
                          style: TextStyle(color: Colors.red[700]),
                          textAlign: TextAlign.center,
                        ),
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
                        Icon(Icons.inbox_outlined,
                            size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No references yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap + to create your first reference',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _refreshRefs,
                  child: ListView.builder(
                    itemCount: refProvider.refs.length,
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (context, index) {
                      final ref = refProvider.refs[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: AppTheme.borderColor),
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
                          borderRadius: BorderRadius.circular(8),
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
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 20),
                                      onPressed: () => _navigateToEdit(ref.id),
                                      tooltip: 'Edit',
                                    ),
                                  ],
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
                                            color: AppTheme.primaryColor,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                if (ref.summary != null &&
                                    ref.summary!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    ref.summary!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: AppTheme.textSecondary,
                                          height: 1.4,
                                        ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                if (ref.hashtags.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: ref.hashtags.map((hashtag) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryColor
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '#${hashtag.name}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.primaryColor,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Text(
                                  _formatRelativeTime(ref.updatedAt),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[500],
                                  ),
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

  String _formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
    }
  }
}
