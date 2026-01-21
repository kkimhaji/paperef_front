import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ref_provider.dart';
import '../../groups/providers/group_provider.dart';
import '../../../core/theme/app_theme.dart';

class CreateRefScreen extends StatefulWidget {
  const CreateRefScreen({super.key});

  @override
  State<CreateRefScreen> createState() => _CreateRefScreenState();
}

class _CreateRefScreenState extends State<CreateRefScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _summaryController = TextEditingController();
  final _contentController = TextEditingController();
  final _hashtagController = TextEditingController();

  // FocusNode 추가
  final _titleFocusNode = FocusNode();
  final _summaryFocusNode = FocusNode();
  final _contentFocusNode = FocusNode();
  final _hashtagFocusNode = FocusNode();

  final List<String> _hashtags = [];
  int? _selectedGroupId;

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    _contentController.dispose();
    _hashtagController.dispose();
    _titleFocusNode.dispose(); // 추가
    _summaryFocusNode.dispose(); // 추가
    _contentFocusNode.dispose(); // 추가
    _hashtagFocusNode.dispose(); // 추가
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

  Future<void> _saveRef() async {
    if (_formKey.currentState!.validate()) {
      final success = await context.read<RefProvider>().createRef(
            title: _titleController.text,
            summary: _summaryController.text.isEmpty
                ? null
                : _summaryController.text,
            content: _contentController.text.isEmpty
                ? null
                : _contentController.text,
            groupId: _selectedGroupId,
            hashtags: _hashtags,
          );

      if (success && mounted) {
        Navigator.of(context).pop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('New Reference'),
        actions: [
          TextButton(
            onPressed: _saveRef,
            child: const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Consumer<GroupProvider>(
              builder: (context, groupProvider, _) {
                return DropdownButtonFormField<int?>(
                  value: _selectedGroupId,
                  decoration: const InputDecoration(
                    labelText: 'Group (Optional)',
                    hintText: 'Select a group',
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('No Group'),
                    ),
                    ...groupProvider.groups.map((group) {
                      return DropdownMenuItem<int?>(
                        value: group.id,
                        child: Text(group.name),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedGroupId = value;
                    });
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              focusNode: _titleFocusNode, // 추가
              decoration: const InputDecoration(
                labelText: 'Title *',
                hintText: 'Enter reference title',
              ),
              textInputAction: TextInputAction.next, // 추가
              onFieldSubmitted: (_) {
                // 추가
                _summaryFocusNode.requestFocus();
              },
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
              focusNode: _summaryFocusNode, // 추가
              decoration: const InputDecoration(
                labelText: 'Summary',
                hintText: 'Brief summary for card view',
              ),
              maxLines: 3,
              textInputAction: TextInputAction.next, // 추가
              onFieldSubmitted: (_) {
                // 추가
                _contentFocusNode.requestFocus();
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contentController,
              focusNode: _contentFocusNode, // 추가
              decoration: const InputDecoration(
                labelText: 'Content',
                hintText: 'Detailed content',
              ),
              maxLines: 10,
              textInputAction: TextInputAction.next, // 추가
              onFieldSubmitted: (_) {
                // 추가
                _hashtagFocusNode.requestFocus();
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _hashtagController,
                    focusNode: _hashtagFocusNode, // 추가
                    decoration: const InputDecoration(
                      labelText: 'Hashtag',
                      hintText: 'Add hashtag',
                    ),
                    textInputAction: TextInputAction.done, // 추가
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
                runSpacing: 8,
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
