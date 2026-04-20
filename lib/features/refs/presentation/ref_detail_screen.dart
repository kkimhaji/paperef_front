import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/widget/responseive_container.dart';
import '../providers/ref_provider.dart';
import '../../../shared/models/ref.dart';
import '../../../core/theme/app_theme.dart';
import 'ref_form_screen.dart';
import '../../groups/providers/group_provider.dart';

class RefDetailScreen extends StatefulWidget {
  final int refId;

  const RefDetailScreen({super.key, required this.refId});

  @override
  State<RefDetailScreen> createState() => _RefDetailScreenState();
}

class _RefDetailScreenState extends State<RefDetailScreen> {
  Ref? _ref;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRef();
  }

  Future<void> _loadRef() async {
    setState(() => _isLoading = true);
    final ref = await context.read<RefProvider>().fetchRef(widget.refId);
    if (mounted) {
      setState(() {
        _ref = ref;
        _isLoading = false;
      });
    }
  }

  Future<void> _openUrl(LinkableElement link) async {
    final uri = Uri.parse(link.url);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch ${link.url}');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Could not open link: ${link.url}'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _navigateToEdit() async {
    if (_ref == null) return;
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => RefFormScreen(ref: _ref)),
    );
    if (result == true && mounted) await _loadRef();
  }

  Future<void> _deleteRef() async {
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
      final success = await context.read<RefProvider>().deleteRef(widget.refId);
      if (success && mounted) Navigator.of(context).pop(true);
    }
  }

  void _copyAll() {
    if (_ref == null) return;
    final buffer = StringBuffer();
    buffer.writeln(_ref!.title);

    if (_ref!.summaries.isNotEmpty) {
      buffer.writeln();
      for (int i = 0; i < _ref!.summaries.length; i++) {
        final label =
            _ref!.summaries.length > 1 ? 'Summary ${i + 1}' : 'Summary';
        buffer.writeln('$label: ${_ref!.summaries[i]}');
      }
    }

    if (_ref!.content != null && _ref!.content!.isNotEmpty) {
      buffer.writeln();
      buffer.write(_ref!.content);
    }

    Clipboard.setData(ClipboardData(text: buffer.toString().trim()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copied to clipboard')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Reference Detail')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_ref == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Reference Detail')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text('Reference not found',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: AppTheme.textSecondary)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Reference Detail'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all_outlined),
            onPressed: _copyAll,
            tooltip: 'Copy all',
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: _navigateToEdit,
            tooltip: 'Edit',
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'delete') _deleteRef();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  Icon(Icons.delete_outline, size: 20, color: Colors.red),
                  SizedBox(width: 12),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ]),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadRef,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: ResponsiveContainer.paddingOf(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_ref!.groupName != null) ...[
                      Row(
                        children: [
                          Icon(Icons.folder_outlined,
                              size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _ref!.groupName!,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[500]),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    SelectableText(
                      _ref!.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    if (_ref!.hashtags.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: _ref!.hashtags
                            .map(
                              (t) => InkWell(
                                onTap: () {
                                  context
                                      .read<GroupProvider>()
                                      .selectGroup(null);
                                  context.read<RefProvider>().fetchRefs(
                                        hashtag: t.name,
                                      );
                                  Navigator.of(context).pop(false); // 목록으로 돌아가기
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color:
                                        AppTheme.primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text('#${t.name}',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.primaryColor,
                                          fontWeight: FontWeight.w500)),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),

              // Summaries
              if (_ref!.summaries.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _ref!.summaries.length > 1 ? 'Summaries' : 'Summary',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                      ),
                      const SizedBox(height: 10),
                      ..._ref!.summaries.asMap().entries.map(
                            (entry) => Padding(
                              padding:
                                  EdgeInsets.only(top: entry.key > 0 ? 12 : 0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_ref!.summaries.length > 1) ...[
                                    Container(
                                      margin: const EdgeInsets.only(
                                          top: 2, right: 10),
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: Colors.green[100],
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${entry.key + 1}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green[700],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                  Expanded(
                                    child: SelectableLinkify(
                                      text: entry.value,
                                      style:
                                          Theme.of(context).textTheme.bodyLarge,
                                      linkStyle: TextStyle(
                                        color: AppTheme.primaryColor,
                                        decoration: TextDecoration.underline,
                                      ),
                                      onOpen: _openUrl,
                                      options:
                                          const LinkifyOptions(humanize: false),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
              ],

              // Content
              if (_ref!.content != null && _ref!.content!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Content',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                      ),
                      const SizedBox(height: 8),
                      SelectableLinkify(
                        text: _ref!.content!,
                        style: Theme.of(context).textTheme.bodyLarge,
                        linkStyle: TextStyle(
                          color: AppTheme.primaryColor,
                          decoration: TextDecoration.underline,
                        ),
                        onOpen: _openUrl,
                        options: const LinkifyOptions(humanize: false),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
