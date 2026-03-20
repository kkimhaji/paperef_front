import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/widget/responseive_container.dart';
import '../providers/ref_provider.dart';
import '../../groups/providers/group_provider.dart';
import '../../groups/presentation/app_drawer.dart';
import 'ref_detail_screen.dart';
import 'ref_form_screen.dart';
import '../../../core/theme/app_theme.dart';

class RefsListScreen extends StatefulWidget {
  const RefsListScreen({super.key});

  @override
  State<RefsListScreen> createState() => _RefsListScreenState();
}

class _RefsListScreenState extends State<RefsListScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  bool _isSearching = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshRefs();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    // 하단 200px 남았을 때 다음 페이지 요청
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<RefProvider>().fetchMoreRefs();
    }
  }
  // ── Search ────────────────────────────────────────────────────────────────

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  void _performSearch(String query) {
    final groupId = context.read<GroupProvider>().selectedGroupId;
    final refProvider = context.read<RefProvider>();
    refProvider.fetchRefs(
      search: query.trim().isEmpty ? null : query.trim(),
      groupId: groupId,
      hashtag: refProvider.selectedHashtag,
      includeSubgroups: refProvider.includeSubgroups,
    );
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _isSearching = false;
    });
    final groupId = context.read<GroupProvider>().selectedGroupId;
    final refProvider = context.read<RefProvider>();
    refProvider.fetchRefs(
      groupId: groupId,
      hashtag: refProvider.selectedHashtag,
      includeSubgroups: refProvider.includeSubgroups,
    );
  }

  Future<void> _refreshRefs() async {
    final groupId = context.read<GroupProvider>().selectedGroupId;
    final refProvider = context.read<RefProvider>();
    final groupProvider = context.read<GroupProvider>();

    await refProvider.fetchRefs(
      groupId: groupId,
      search: refProvider.searchQuery,
      hashtag: refProvider.selectedHashtag,
      includeSubgroups: refProvider.includeSubgroups,
    );
    await refProvider.fetchHashtags();
    await groupProvider.fetchGroupTree();
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  Future<void> _navigateToEdit(int refId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final ref = await context.read<RefProvider>().fetchRef(refId);

    if (mounted) {
      Navigator.of(context).pop();
      if (ref != null) {
        final result = await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => RefFormScreen(ref: ref)),
        );
        if (result == true) _refreshRefs();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load reference details')),
        );
      }
    }
  }

  Future<void> _deleteRef(int refId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Reference'),
        content: const Text(
          'Are you sure you want to delete this reference? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await context.read<RefProvider>().deleteRef(refId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Reference deleted successfully'
                : 'Failed to delete reference'),
            backgroundColor: success ? null : Colors.red,
          ),
        );
        if (success) _refreshRefs();
      }
    }
  }

  Future<void> _openUrl(LinkableElement link) async {
    final uri = Uri.parse(link.url);
    try {
      if (!await launchUrl(uri,
          mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank')) {
        throw Exception('Could not launch ${link.url}');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open link: ${link.url}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ── AppBar title (Breadcrumb) ─────────────────────────────────────────────

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

    if (groupProvider.selectedGroupId == null) {
      return const Text('All References');
    }

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
              if (i > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.chevron_right,
                      size: 16, color: Colors.grey[600]),
                ),
              InkWell(
                onTap: () {
                  final groupId = groupProvider.breadcrumbs[i]['id'] as int;
                  if (groupId != groupProvider.selectedGroupId) {
                    groupProvider.selectGroup(groupId);
                    context.read<RefProvider>().fetchRefs(
                          groupId: groupId,
                          includeSubgroups:
                              context.read<RefProvider>().includeSubgroups,
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

    // Fallback
    try {
      final group = groupProvider.groups
          .firstWhere((g) => g.id == groupProvider.selectedGroupId);
      return Text(group.name);
    } catch (_) {
      return const Text('References');
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // iPad 스플릿 뷰(좁은 창)에서 시스템 버튼과 겹치지 않도록 패딩 추가
    final isNarrowWindow = screenWidth < 600;
    final extraLeadingPadding = isNarrowWindow ? 52.0 : 0.0;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 56 + extraLeadingPadding,
        leading: Padding(
          padding: EdgeInsets.only(left: extraLeadingPadding),
          child: Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
        ),
        title: Consumer<GroupProvider>(
          builder: (_, groupProvider, __) =>
              _buildBreadcrumbTitle(groupProvider),
        ),
        actions: [
          Consumer2<GroupProvider, RefProvider>(
            builder: (_, groupProvider, refProvider, __) {
              if (groupProvider.selectedGroupId != null &&
                  groupProvider.selectedGroupId != 0) {
                return IconButton(
                  icon: Icon(refProvider.includeSubgroups
                      ? Icons.account_tree
                      : Icons.folder),
                  tooltip: refProvider.includeSubgroups
                      ? 'Include subgroups'
                      : 'Current group only',
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
                setState(() => _isSearching = true);
                WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _searchFocusNode.requestFocus());
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
          // ── 검색 필터 표시 ───────────────────────────────────────────────
          Consumer<RefProvider>(
            builder: (_, refProvider, __) {
              if (refProvider.searchQuery == null ||
                  refProvider.searchQuery!.isEmpty) {
                return const SizedBox.shrink();
              }
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: AppTheme.primaryColor.withOpacity(0.1),
                child: Row(
                  children: [
                    Icon(Icons.search, size: 16, color: AppTheme.primaryColor),
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
                      icon: Icon(Icons.close,
                          size: 18, color: AppTheme.primaryColor),
                      onPressed: refProvider.clearSearch,
                    ),
                  ],
                ),
              );
            },
          ),

          // ── 해시태그 필터 ────────────────────────────────────────────────
          Consumer<RefProvider>(
            builder: (ctx, refProvider, __) {
              if (refProvider.hashtags.isEmpty) return const SizedBox.shrink();
              return Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border:
                      Border(bottom: BorderSide(color: AppTheme.dividerColor)),
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
                          onSelected: (_) => refProvider.fetchRefs(
                            hashtag: hashtag,
                            groupId: ctx.read<GroupProvider>().selectedGroupId,
                            search: refProvider.searchQuery,
                            includeSubgroups: refProvider.includeSubgroups,
                          ),
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

          // ── 레퍼런스 리스트 ──────────────────────────────────────────────
          Expanded(
            child: Consumer<RefProvider>(
              builder: (_, refProvider, __) {
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
                        Text('Error: ${refProvider.error}',
                            style: TextStyle(color: Colors.red[700]),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                            onPressed: _refreshRefs,
                            child: const Text('Retry')),
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
                        Text('No references yet',
                            style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        Text('Tap + to create your first reference',
                            style: TextStyle(
                                fontSize: 14, color: Colors.grey[500])),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _refreshRefs,
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount:
                        refProvider.refs.length + (refProvider.hasMore ? 1 : 0),
                    padding: ResponsiveContainer.paddingOf(context),
                    itemBuilder: (ctx, index) {
                      if (index == refProvider.refs.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

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
                            final result = await Navigator.of(ctx).push<bool>(
                              MaterialPageRoute(
                                builder: (_) => RefDetailScreen(refId: ref.id),
                              ),
                            );
                            if (result == true) _refreshRefs();
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 제목 + 메뉴 버튼
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        ref.title,
                                        style: Theme.of(ctx)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                                fontWeight: FontWeight.bold),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    PopupMenuButton<String>(
                                      icon: Icon(Icons.more_vert,
                                          color: Colors.grey[600], size: 20),
                                      onSelected: (value) async {
                                        if (value == 'edit') {
                                          await _navigateToEdit(ref.id);
                                        } else if (value == 'delete') {
                                          await _deleteRef(ref.id);
                                        }
                                      },
                                      itemBuilder: (_) => [
                                        const PopupMenuItem(
                                          value: 'edit',
                                          child: Row(children: [
                                            Icon(Icons.edit_outlined, size: 18),
                                            SizedBox(width: 12),
                                            Text('Edit'),
                                          ]),
                                        ),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Row(children: [
                                            Icon(Icons.delete_outline,
                                                size: 18, color: Colors.red),
                                            SizedBox(width: 12),
                                            Text('Delete',
                                                style: TextStyle(
                                                    color: Colors.red)),
                                          ]),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),

                                // 그룹명
                                if (ref.groupName != null) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(Icons.folder_outlined,
                                          size: 14,
                                          color: AppTheme.primaryColor),
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

                                // Summaries (최대 3개)
                                if (ref.summaries.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  ...ref.summaries.asMap().entries.map(
                                        (entry) => Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 4),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              if (ref.summaries.length > 1) ...[
                                                Container(
                                                  margin: const EdgeInsets.only(
                                                      top: 3, right: 6),
                                                  width: 16,
                                                  height: 16,
                                                  decoration: BoxDecoration(
                                                    color: Colors.green[100],
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            4),
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      '${entry.key + 1}',
                                                      style: TextStyle(
                                                        fontSize: 9,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color:
                                                            Colors.green[700],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ] else ...[
                                                Container(
                                                  margin: const EdgeInsets.only(
                                                      top: 7, right: 6),
                                                  width: 4,
                                                  height: 4,
                                                  decoration: BoxDecoration(
                                                    color: Colors.green[400],
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                              ],
                                              Expanded(
                                                child: Linkify(
                                                  text: entry.value,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: Theme.of(ctx)
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.copyWith(
                                                        color: AppTheme
                                                            .textSecondary,
                                                        height: 1.4,
                                                      ),
                                                  linkStyle: TextStyle(
                                                    color:
                                                        AppTheme.primaryColor,
                                                    decoration: TextDecoration
                                                        .underline,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                  onOpen: _openUrl,
                                                  options: const LinkifyOptions(
                                                      humanize: false),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                ],

                                // 해시태그
                                if (ref.hashtags.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: ref.hashtags
                                        .map((hashtag) => Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 3),
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
                                            ))
                                        .toList(),
                                  ),
                                ],

                                // 업데이트 시간
                                const SizedBox(height: 8),
                                Text(
                                  _formatRelativeTime(ref.updatedAt),
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.grey[500]),
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
            MaterialPageRoute(builder: (_) => const RefFormScreen()),
          );
          if (result == true) _refreshRefs();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  String _formatRelativeTime(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
  }
}
