import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  // FocusNode
  final _titleFocusNode = FocusNode();
  final _summaryFocusNode = FocusNode();
  final _contentFocusNode = FocusNode();
  final _hashtagFocusNode = FocusNode();

  final List<String> _hashtags = [];
  int? _selectedGroupId;

  @override
  void initState() {
    super.initState();
    // 그룹 트리 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final groupProvider = context.read<GroupProvider>();
      if (groupProvider.groupTree.isEmpty) {
        groupProvider.fetchGroupTree();
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    _contentController.dispose();
    _hashtagController.dispose();
    _titleFocusNode.dispose();
    _summaryFocusNode.dispose();
    _contentFocusNode.dispose();
    _hashtagFocusNode.dispose();
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
                // 플랫한 그룹 리스트 가져오기 (서브그룹 포함)
                final flatGroups = groupProvider.getFlatGroupList();

                return DropdownButtonFormField<int?>(
                  value: _selectedGroupId,
                  decoration: const InputDecoration(
                    labelText: 'Group (Optional)',
                    hintText: 'Select a group',
                  ),
                  dropdownColor: Colors.white,
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('No Group'),
                    ),
                    ...flatGroups.map((group) {
                      return DropdownMenuItem<int?>(
                        value: group.id,
                        child: Text('${group.name}'),
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

            // Title 필드
            Focus(
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.tab) {
                  final isShiftPressed =
                      HardwareKeyboard.instance.isShiftPressed;
                  if (!isShiftPressed) {
                    _summaryFocusNode.requestFocus();
                    return KeyEventResult.handled;
                  }
                }
                return KeyEventResult.ignored;
              },
              child: TextFormField(
                controller: _titleController,
                focusNode: _titleFocusNode,
                decoration: const InputDecoration(
                  labelText: 'Title *',
                  hintText: 'Enter reference title',
                ),
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) {
                  _summaryFocusNode.requestFocus();
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 16),

            // Summary 필드
            Focus(
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.tab) {
                  final isShiftPressed =
                      HardwareKeyboard.instance.isShiftPressed;
                  if (!isShiftPressed) {
                    _contentFocusNode.requestFocus();
                    return KeyEventResult.handled;
                  } else {
                    _titleFocusNode.requestFocus();
                    return KeyEventResult.handled;
                  }
                }
                return KeyEventResult.ignored;
              },
              child: TextFormField(
                controller: _summaryController,
                focusNode: _summaryFocusNode,
                decoration: const InputDecoration(
                  labelText: 'Summary',
                  hintText: 'Brief summary for card view',
                ),
                maxLines: 3,
                textInputAction: TextInputAction.newline,
              ),
            ),
            const SizedBox(height: 16),

            // Content 필드
            Focus(
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.tab) {
                  final isShiftPressed =
                      HardwareKeyboard.instance.isShiftPressed;
                  if (!isShiftPressed) {
                    _hashtagFocusNode.requestFocus();
                    return KeyEventResult.handled;
                  } else {
                    _summaryFocusNode.requestFocus();
                    return KeyEventResult.handled;
                  }
                }
                return KeyEventResult.ignored;
              },
              child: TextFormField(
                controller: _contentController,
                focusNode: _contentFocusNode,
                decoration: const InputDecoration(
                  labelText: 'Content',
                  hintText: 'Detailed content',
                ),
                maxLines: 10,
                textInputAction: TextInputAction.newline,
              ),
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
                    textInputAction: TextInputAction.done,
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
