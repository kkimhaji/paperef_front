import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ref_provider.dart';
import '../../groups/providers/group_provider.dart';
import '../../groups/presentation/app_drawer.dart';
import 'ref_detail_screen.dart';
import 'ref_form_screen.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/ref.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshRefs());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ── Search ────────────────────────────────────────────────────────────────

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce =
        Timer(const Duration(milliseconds: 500), () => _performSearch(query));
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
    final groupProvider = context.read<GroupProvider>();
    final refProvider = context.read<RefProvider>();
    await Future.wait([
      refProvider.fetchRefs(
        groupId: groupProvider.selectedGroupId,
        search: refProvider.searchQuery,
        hashtag: refProvider.selectedHashtag,
        includeSubgroups: refProvider.includeSubgroups,
      ),
      refProvider.fetchHashtags(),
      groupProvider.fetchGroupTree(),
    ]);
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _navigateToEdit(int refId) async {
    if (!mounted) return;
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
            'Are you sure you want to delete this reference? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<RefProvider>().deleteRef(refId);
    }
  }

  // ── AppBar title ──────────────────────────────────────────────────────────
  String _resolveGroupName(GroupProvider gp) {
    if (gp.selectedGroupId == null) return 'All References';
    if (gp.selectedGroupId == 0) return 'Ungrouped';
    // breadcrumbs가 있으면 마지막 항목이 현재 그룹명
    if (gp.breadcrumbs.isNotEmpty) {
      return gp.breadcrumbs.last['name'] as String;
    }
    // fallback: groups 리스트에서 찾기
    try {
      return gp.groups.firstWhere((g) => g.id == gp.selectedGroupId).name;
    } catch (_) {
      return 'References';
    }
  }

  Widget _buildBreadcrumbTitle(GroupProvider gp) {
    if (_isSearching) {
      return TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        decoration: const InputDecoration(
          hintText: 'Search...',
          border: InputBorder.none,
        ),
        onChanged: _onSearchChanged,
        autofocus: true,
      );
    }
    return Text(_resolveGroupName(gp), overflow: TextOverflow.ellipsis);
  }
  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 600;
    final extraLeadingPadding = isWide ? 52.0 : 0.0;

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
          builder: (_, gp, __) => _buildBreadcrumbTitle(gp),
        ),
        actions: [
          Consumer2<GroupProvider, RefProvider>(
            builder: (_, gp, rp, __) {
              if (gp.selectedGroupId != null && gp.selectedGroupId != 0) {
                return IconButton(
                  icon: Icon(
                      rp.includeSubgroups ? Icons.account_tree : Icons.folder),
                  tooltip: rp.includeSubgroups
                      ? 'Include subgroups'
                      : 'Current group only',
                  onPressed: () {
                    rp.toggleIncludeSubgroups();
                    rp.fetchRefs(
                      groupId: gp.selectedGroupId,
                      search: rp.searchQuery,
                      hashtag: rp.selectedHashtag,
                      includeSubgroups: rp.includeSubgroups,
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
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(Icons.close),
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
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshRefs),
        ],
      ),
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const RefFormScreen()),
          );
          if (result == true) _refreshRefs();
        },
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // ── Search query indicator ─────────────────────────────────────────
          Consumer<RefProvider>(
            builder: (_, rp, __) {
              if (rp.searchQuery == null || rp.searchQuery!.isEmpty) {
                return const SizedBox.shrink();
              }
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: AppTheme.primaryColor.withOpacity(0.05),
                child: Row(
                  children: [
                    Icon(Icons.search, size: 16, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Results for "${rp.searchQuery}"',
                        style: TextStyle(
                            color: AppTheme.primaryColor, fontSize: 13),
                      ),
                    ),
                    GestureDetector(
                      onTap: _clearSearch,
                      child: Icon(Icons.close,
                          size: 16, color: AppTheme.primaryColor),
                    ),
                  ],
                ),
              );
            },
          ),

          // ── Hashtag chips ──────────────────────────────────────────────────
          Consumer<RefProvider>(
            builder: (ctx, rp, __) {
              if (rp.hashtags.isEmpty) return const SizedBox.shrink();
              return Container(
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
                    children: rp.hashtags.map((hashtag) {
                      final isSelected = rp.selectedHashtag == hashtag;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text('#$hashtag'),
                          selected: isSelected,
                          onSelected: (_) => rp.fetchRefs(
                            hashtag: isSelected ? null : hashtag,
                            groupId: ctx.read<GroupProvider>().selectedGroupId,
                            search: rp.searchQuery,
                            includeSubgroups: rp.includeSubgroups,
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

          // ── Ref list ────────────────────────────────────────────────────────
          Expanded(
            child: Consumer<RefProvider>(
              builder: (_, rp, __) {
                if (rp.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (rp.error != null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline,
                            size: 48, color: Colors.red[300]),
                        const SizedBox(height: 16),
                        Text('Error: ${rp.error}',
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
                if (rp.refs.isEmpty) {
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
                    itemCount: rp.refs.length,
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (ctx, index) =>
                        _buildRefCard(ctx, rp.refs[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRefCard(BuildContext context, Ref ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppTheme.borderColor),
      ),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => RefDetailScreen(refId: ref.id)),
          );
          if (result == true) _refreshRefs();
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title + menu
              Row(
                children: [
                  Expanded(
                    child: Text(
                      ref.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert,
                        size: 20, color: Colors.grey[600]),
                    onSelected: (value) {
                      if (value == 'edit') _navigateToEdit(ref.id);
                      if (value == 'delete') _deleteRef(ref.id);
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
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ]),
                      ),
                    ],
                  ),
                ],
              ),

              // Summaries
              if (ref.summaries.isNotEmpty) ...[
                const SizedBox(height: 8),
                ...ref.summaries.asMap().entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (ref.summaries.length > 1) ...[
                              Container(
                                margin: const EdgeInsets.only(top: 3, right: 6),
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: Colors.green[100],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Center(
                                  child: Text(
                                    '${entry.key + 1}',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green[700],
                                    ),
                                  ),
                                ),
                              ),
                            ] else ...[
                              Container(
                                margin: const EdgeInsets.only(top: 6, right: 6),
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.green[400],
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                            Expanded(
                              child: Text(
                                entry.value,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: AppTheme.textSecondary,
                                    ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
              ],

              // Group name
              if (ref.groupName != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.folder_outlined,
                        size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        ref.groupName!,
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],

              // Hashtags
              if (ref.hashtags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: ref.hashtags
                      .map(
                        (t) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '#${t.name}',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
