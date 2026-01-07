import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/paper_provider.dart';

class CreatePaperScreen extends StatefulWidget {
  const CreatePaperScreen({super.key});

  @override
  State<CreatePaperScreen> createState() => _CreatePaperScreenState();
}

class _CreatePaperScreenState extends State<CreatePaperScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _summaryController = TextEditingController();
  final _contentController = TextEditingController();
  final _hashtagController = TextEditingController();
  final List<String> _hashtags = [];

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
      final success = await context.read<PaperProvider>().createPaper(
            title: _titleController.text,
            summary: _summaryController.text.isEmpty
                ? null
                : _summaryController.text,
            content: _contentController.text.isEmpty
                ? null
                : _contentController.text,
            hashtags: _hashtags,
          );

      if (success && mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Paper'),
        actions: [
          TextButton(
            onPressed: _savePaper,
            child: const Text('Save'),
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
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contentController,
              decoration: const InputDecoration(
                labelText: 'Content',
                hintText: 'Detailed content',
              ),
              maxLines: 10,
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
                    onSubmitted: (_) => _addHashtag(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addHashtag,
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
                    onDeleted: () => _removeHashtag(hashtag),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}
