import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/paper_provider.dart';
import '../../../shared/models/paper.dart';

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
    final paper =
        await context.read<PaperProvider>().fetchPaper(widget.paperId);
    setState(() {
      _paper = paper;
      _isLoading = false;
    });
  }

  Future<void> _deletePaper() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Paper'),
        content: const Text('Are you sure you want to delete this paper?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success =
          await context.read<PaperProvider>().deletePaper(widget.paperId);
      if (success && mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_paper == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Paper not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paper Detail'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deletePaper,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _paper!.title,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: _paper!.hashtags.map((hashtag) {
                return Chip(label: Text('#${hashtag.name}'));
              }).toList(),
            ),
            const SizedBox(height: 24),
            if (_paper!.summary != null) ...[
              Text(
                'Summary',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(_paper!.summary!),
              const SizedBox(height: 24),
            ],
            if (_paper!.content != null) ...[
              Text(
                'Content',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(_paper!.content!),
            ],
          ],
        ),
      ),
    );
  }
}
