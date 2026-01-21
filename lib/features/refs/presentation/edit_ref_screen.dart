import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ref_provider.dart';
import '../../groups/providers/group_provider.dart';
import '../../../shared/models/ref.dart';
import '../../../core/theme/app_theme.dart';

class EditRefScreen extends StatefulWidget {
  final Ref ref;

  const EditRefScreen({super.key, required this.ref});

  @override
  State<EditRefScreen> createState() => _EditRefScreenState();
}

class _EditRefScreenState extends State<EditRefScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _summaryController;
  late final TextEditingController _contentController;
  final _hashtagController = TextEditingController();

  // FocusNode 추가
  final _titleFocusNode = FocusNode();
  final _summaryFocusNode = FocusNode();
  final _contentFocusNode = FocusNode();
  final _hashtagFocusNode = FocusNode();

  late List<String> _hashtags;
  late int? _selectedGroupId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.ref.title);
    _summaryController = TextEditingController(text: widget.ref.summary ?? '');
    _contentController = TextEditingController(text: widget.ref.content ?? '');
    _hashtags = widget.ref.hashtags.map((tag) => tag.name).toList();
    _selectedGroupId = widget.ref.groupId;
  }

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
      setState(() {
        _isSaving = true;
      });

      final success = await context.read<RefProvider>().updateRef(
            id: widget.ref.id,
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

      if (mounted) {
        setState(() {
          _isSaving = false;
        });

        if (success) {
          Navigator.of(context).pop(true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update reference')),
          );
        }
      }
    }
  }

  Future<void> _deleteRef() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Reference'),
        content: const Text(
            'Are you sure you want to delete this reference? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
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
          await context.read<RefProvider>().deleteRef(widget.ref.id);

      if (mounted) {
        setState(() {
          _isSaving = false;
        });

        if (success) {
          Navigator.of(context).pop(true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete reference')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Edit Reference'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _isSaving ? null : _deleteRef,
            tooltip: 'Delete',
          ),
          TextButton(
            onPressed: _isSaving ? null : _saveRef,
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
                  onChanged: _isSaving
                      ? null
                      : (value) {
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
              focusNode: _titleFocusNode,
              decoration: const InputDecoration(
                labelText: 'Title *',
                hintText: 'Enter reference title',
              ),
              enabled: !_isSaving,
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) {
                // Title은 한 줄이므로 Enter로 이동 OK
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
              focusNode: _summaryFocusNode,
              decoration: const InputDecoration(
                labelText: 'Summary',
                hintText: 'Brief summary for card view',
              ),
              maxLines: 3,
              enabled: !_isSaving,
              textInputAction: TextInputAction.newline, // next → newline 변경
              // onFieldSubmitted 제거 - Enter는 줄바꿈만
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contentController,
              focusNode: _contentFocusNode,
              decoration: const InputDecoration(
                labelText: 'Content',
                hintText: 'Detailed content',
              ),
              maxLines: 10,
              enabled: !_isSaving,
              textInputAction: TextInputAction.newline, // next → newline 변경
              // onFieldSubmitted 제거 - Enter는 줄바꿈만
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _hashtagController,
                    focusNode: _hashtagFocusNode,
                    decoration: const InputDecoration(
                      labelText: 'Hashtag',
                      hintText: 'Add hashtag',
                    ),
                    enabled: !_isSaving,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) =>
                        _addHashtag(), // Hashtag는 한 줄이므로 Enter로 추가 OK
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
                runSpacing: 8,
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
