import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/paper_provider.dart';
import '../../../shared/models/paper.dart';

class EditPaperScreen extends StatefulWidget {
  final Paper paper;

  const EditPaperScreen({super.key, required this.paper});

  @override
  State<EditPaperScreen> createState() => _EditPaperScreenState();
}

class _EditPaperScreenState extends State<EditPaperScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _summaryController;
  late final TextEditingController _contentController;
  final _hashtagController = TextEditingController();
  late List<String> _hashtags;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Paper 객체에서 데이터를 초기화
    _titleController = TextEditingController(text: widget.paper.title);
    _summaryController =
        TextEditingController(text: widget.paper.summary ?? '');
    _contentController =
        TextEditingController(text: widget.paper.content ?? '');
    _hashtags = widget.paper.hashtags.map((tag) => tag.name).toList();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    _contentController.dispose();
    _hashtagController.dispose();
    super.dispose();
  }

  void _addHashtag() {
    final hashtag = _hashtagController.text.trim();
    if (hashtag.isNotEmpty && !_hashtags.contains(hashtag)) {
      setState(() {
        _hashtags.add(hashtag);
        _hashtagController.clear();
      });
    }
  }

  void _removeHashtag(String hashtag) {
    setState(() {
      _hashtags.remove(hashtag);
    });
  }

  Future<void> _savePaper() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSaving = true;
      });

      final success = await context.read<PaperProvider>().updatePaper(
            id: widget.paper.id,
            title: _titleController.text,
            summary: _summaryController.text.isEmpty
                ? null
                : _summaryController.text,
            content: _contentController.text.isEmpty
                ? null
                : _contentController.text,
            hashtags: _hashtags,
          );

      if (mounted) {
        setState(() {
          _isSaving = false;
        });

        if (success) {
          Navigator.of(context).pop(true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update paper')),
          );
        }
      }
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
      setState(() {
        _isSaving = true;
      });

      final success =
          await context.read<PaperProvider>().deletePaper(widget.paper.id);

      if (mounted) {
        setState(() {
          _isSaving = false;
        });

        if (success) {
          Navigator.of(context).pop(true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete paper')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Paper'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _isSaving ? null : _deletePaper,
            tooltip: 'Delete',
          ),
          TextButton(
            onPressed: _isSaving ? null : _savePaper,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title *',
                hintText: 'Enter paper title',
              ),
              enabled: !_isSaving,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _summaryController,
              decoration: const InputDecoration(
                labelText: 'Summary',
                hintText: 'Brief summary for card view',
              ),
              maxLines: 3,
              enabled: !_isSaving,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contentController,
              decoration: const InputDecoration(
                labelText: 'Content',
                hintText: 'Detailed content',
              ),
              maxLines: 10,
              enabled: !_isSaving,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _hashtagController,
                    decoration: const InputDecoration(
                      labelText: 'Hashtag',
                      hintText: 'Add hashtag',
                    ),
                    enabled: !_isSaving,
                    onSubmitted: (_) => _addHashtag(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isSaving ? null : _addHashtag,
                  child: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_hashtags.isNotEmpty)
              Wrap(
                spacing: 8,
                children: _hashtags.map((hashtag) {
                  return Chip(
                    label: Text('#$hashtag'),
                    onDeleted: _isSaving ? null : () => _removeHashtag(hashtag),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}
