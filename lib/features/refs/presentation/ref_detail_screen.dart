import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/ref_provider.dart';
import '../../../shared/models/ref.dart';
import 'edit_ref_screen.dart';

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
    setState(() {
      _isLoading = true;
    });

    final ref = await context.read<RefProvider>().fetchRef(widget.refId);

    if (mounted) {
      setState(() {
        _ref = ref;
        _isLoading = false;
      });
    }
  }

  Future<void> _navigateToEdit() async {
    if (_ref == null) return;

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditRefScreen(ref: _ref!),
      ),
    );

    if (result == true && mounted) {
      await _loadRef();
    }
  }

  Future<void> _deleteRef() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Reference'),
        content: const Text(
            'Are you sure you want to delete this reference? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await context.read<RefProvider>().deleteRef(widget.refId);

      if (success && mounted) {
        Navigator.of(context).pop(true);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete reference')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Reference Detail'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_ref == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Reference Detail'),
        ),
        body: const Center(
          child: Text('Reference not found'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reference Detail'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all),
            onPressed: () {
              final buffer = StringBuffer();
              buffer.writeln(_ref!.title);
              buffer.writeln();

              if (_ref!.summary != null && _ref!.summary!.isNotEmpty) {
                buffer.writeln('Summary:');
                buffer.writeln(_ref!.summary);
                buffer.writeln();
              }

              if (_ref!.content != null && _ref!.content!.isNotEmpty) {
                buffer.writeln('Content:');
                buffer.writeln(_ref!.content);
                buffer.writeln();
              }

              if (_ref!.hashtags.isNotEmpty) {
                buffer.write('Tags: ');
                buffer.writeln(
                    _ref!.hashtags.map((tag) => '#${tag.name}').join(' '));
              }

              Clipboard.setData(ClipboardData(text: buffer.toString()));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Full reference copied to clipboard'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            tooltip: 'Copy all',
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _navigateToEdit,
            tooltip: 'Edit',
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deleteRef,
            tooltip: 'Delete',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadRef,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(
                _ref!.title,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Updated: ${_formatDate(_ref!.updatedAt)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 16),
              if (_ref!.hashtags.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _ref!.hashtags.map((hashtag) {
                    return SelectableText(
                      '#${hashtag.name}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
              ],
              if (_ref!.summary != null && _ref!.summary!.isNotEmpty) ...[
                Text(
                  'Summary',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    _ref!.summary!,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                const SizedBox(height: 24),
              ],
              if (_ref!.content != null && _ref!.content!.isNotEmpty) ...[
                Text(
                  'Content',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  _ref!.content!,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        height: 1.6,
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
