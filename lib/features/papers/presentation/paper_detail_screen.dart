import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/paper_provider.dart';
import '../../../shared/models/paper.dart';
import 'edit_paper_screen.dart';

class PaperDetailScreen extends StatefulWidget {
  final int paperId;

  const PaperDetailScreen({super.key, required this.paperId});

  @override
  State<PaperDetailScreen> createState() => _PaperDetailScreenState();
}

class _PaperDetailScreenState extends State<PaperDetailScreen> {
  Paper? _paper;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPaper();
  }

  Future<void> _loadPaper() async {
    setState(() {
      _isLoading = true;
    });

    final paper =
        await context.read<PaperProvider>().fetchPaper(widget.paperId);

    if (mounted) {
      setState(() {
        _paper = paper;
        _isLoading = false;
      });
    }
  }

  Future<void> _navigateToEdit() async {
    if (_paper == null) return;

    // 이미 _paper에 전체 데이터가 있으므로 바로 전달
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditPaperScreen(paper: _paper!), // 전체 Paper 객체 전달
      ),
    );

    // 편집 후 돌아왔을 때 데이터 새로고침
    if (result == true && mounted) {
      await _loadPaper();
    }
  }

  Future<void> _deletePaper() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Paper'),
        content: const Text(
            'Are you sure you want to delete this paper? This action cannot be undone.'),
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
      final success =
          await context.read<PaperProvider>().deletePaper(widget.paperId);

      if (success && mounted) {
        Navigator.of(context).pop(true); // 목록 화면으로 돌아가며 새로고침 신호
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete paper')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Paper Detail'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_paper == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Paper Detail'),
        ),
        body: const Center(
          child: Text('Paper not found'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paper Detail'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _navigateToEdit,
            tooltip: 'Edit',
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deletePaper,
            tooltip: 'Delete',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadPaper,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 제목
              Text(
                _paper!.title,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),

              // 날짜
              Text(
                'Updated: ${_formatDate(_paper!.updatedAt)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 16),

              // 해시태그
              if (_paper!.hashtags.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  children: _paper!.hashtags.map((hashtag) {
                    return Chip(label: Text('#${hashtag.name}'));
                  }).toList(),
                ),
                const SizedBox(height: 24),
              ],

              // 요약
              if (_paper!.summary != null && _paper!.summary!.isNotEmpty) ...[
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
                  child: Text(_paper!.summary!),
                ),
                const SizedBox(height: 24),
              ],

              // 본문
              if (_paper!.content != null && _paper!.content!.isNotEmpty) ...[
                Text(
                  'Content',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  _paper!.content!,
                  style: Theme.of(context).textTheme.bodyLarge,
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
