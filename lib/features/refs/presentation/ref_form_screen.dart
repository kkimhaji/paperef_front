import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import '../providers/ref_provider.dart';
import '../../groups/providers/group_provider.dart';
import '../../../shared/models/ref.dart';
import '../../../core/theme/app_theme.dart';

class RefFormScreen extends StatefulWidget {
  final Ref? ref;

  const RefFormScreen({
    super.key,
    this.ref,
  });

  @override
  State<RefFormScreen> createState() => _RefFormScreenState();
}

class _RefFormScreenState extends State<RefFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  late final TextEditingController _titleController;
  late final TextEditingController _summaryController;
  late final TextEditingController _contentController;
  final _hashtagController = TextEditingController();

  // FocusNodes
  final _titleFocusNode = FocusNode();
  final _summaryFocusNode = FocusNode();
  final _contentFocusNode = FocusNode();
  final _hashtagFocusNode = FocusNode();

  // State
  late List<String> _hashtags;
  late int? _selectedGroupId;
  bool _isSaving = false;

  bool get isEditMode => widget.ref != null;

  @override
  void initState() {
    super.initState();

    _titleController = TextEditingController(
      text: widget.ref?.title ?? '',
    );
    _summaryController = TextEditingController(
      text: widget.ref?.summary ?? '',
    );
    _contentController = TextEditingController(
      text: widget.ref?.content ?? '',
    );
    _hashtags = widget.ref?.hashtags.map((tag) => tag.name).toList() ?? [];
    _selectedGroupId = widget.ref?.groupId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final groupProvider = context.read<GroupProvider>();
      if (groupProvider.groupTree.isEmpty) {
        groupProvider.fetchGroupTree();
      }

      // 해시태그 목록 로드
      context.read<RefProvider>().fetchHashtags();
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

  void _addHashtag(String hashtag) {
    final cleanHashtag = hashtag.trim().toLowerCase();
    if (cleanHashtag.isNotEmpty && !_hashtags.contains(cleanHashtag)) {
      setState(() {
        _hashtags.add(cleanHashtag);
      });
      _hashtagController.clear();
    }
  }

  void _removeHashtag(String hashtag) {
    setState(() {
      _hashtags.remove(hashtag);
    });
  }

  String _buildGroupPrefix(int depth) {
    if (depth == 0) return '';
    return '${'  ' * depth}└ ';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final refProvider = context.read<RefProvider>();
    bool success;

    if (isEditMode) {
      success = await refProvider.updateRef(
        id: widget.ref!.id,
        title: _titleController.text.trim(),
        summary: _summaryController.text.trim().isEmpty
            ? null
            : _summaryController.text.trim(),
        content: _contentController.text.trim().isEmpty
            ? null
            : _contentController.text.trim(),
        groupId: _selectedGroupId,
        hashtags: _hashtags,
      );
    } else {
      success = await refProvider.createRef(
        title: _titleController.text.trim(),
        summary: _summaryController.text.trim().isEmpty
            ? null
            : _summaryController.text.trim(),
        content: _contentController.text.trim().isEmpty
            ? null
            : _contentController.text.trim(),
        groupId: _selectedGroupId,
        hashtags: _hashtags,
      );
    }

    if (mounted) {
      setState(() => _isSaving = false);

      if (success) {
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEditMode
                  ? 'Failed to update reference'
                  : 'Failed to create reference',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _delete() async {
    if (!isEditMode) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Delete Reference'),
        content: const Text(
          'Are you sure you want to delete this reference? This action cannot be undone.',
        ),
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
      setState(() => _isSaving = true);

      final success =
          await context.read<RefProvider>().deleteRef(widget.ref!.id);

      if (mounted) {
        setState(() => _isSaving = false);

        if (success) {
          Navigator.of(context).pop(true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to delete reference'),
              backgroundColor: Colors.red,
            ),
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
        title: Text(isEditMode ? 'Edit Reference' : 'New Reference'),
        actions: [
          if (isEditMode)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _isSaving ? null : _delete,
              tooltip: 'Delete',
            ),
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
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
            // 그룹 선택 드롭다운
            Consumer<GroupProvider>(
              builder: (context, groupProvider, _) {
                final flatGroups = groupProvider.getFlatGroupList();

                return DropdownButtonFormField2<int?>(
                  value: _selectedGroupId,
                  decoration: const InputDecoration(
                    labelText: 'Group (Optional)',
                    hintText: 'Select a group',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  isExpanded: true,
                  dropdownStyleData: DropdownStyleData(
                    maxHeight: 400,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    offset: const Offset(0, -5),
                    scrollbarTheme: ScrollbarThemeData(
                      radius: const Radius.circular(40),
                      thickness: MaterialStateProperty.all(6),
                      thumbVisibility: MaterialStateProperty.all(true),
                    ),
                  ),
                  menuItemStyleData: const MenuItemStyleData(
                    height: 48,
                    padding: EdgeInsets.symmetric(horizontal: 16),
                  ),
                  buttonStyleData: const ButtonStyleData(
                    // height: 56,
                    padding: EdgeInsets.only(right: 8),
                  ),
                  iconStyleData: const IconStyleData(
                    icon: Icon(Icons.arrow_drop_down),
                    iconSize: 24,
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('No Group'),
                    ),
                    ...flatGroups.map((group) {
                      final depth = groupProvider.getGroupDepth(group.id);
                      final prefix = _buildGroupPrefix(depth);

                      return DropdownMenuItem<int?>(
                        value: group.id,
                        child: Text('$prefix${group.name}'),
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

            // 제목
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
                enabled: !_isSaving,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) => _summaryFocusNode.requestFocus(),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 16),

            // 요약
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
                enabled: !_isSaving,
                maxLines: 3,
                textInputAction: TextInputAction.newline,
              ),
            ),
            const SizedBox(height: 16),

            // 내용
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
                enabled: !_isSaving,
                maxLines: 10,
                textInputAction: TextInputAction.newline,
              ),
            ),
            const SizedBox(height: 16),

            // 해시태그 자동완성 입력
            Consumer<RefProvider>(
              builder: (context, refProvider, _) {
                final availableHashtags = refProvider.hashtags
                    .where((tag) => !_hashtags.contains(tag))
                    .toList();

                return Autocomplete<String>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return const Iterable<String>.empty();
                    }

                    // 입력된 텍스트로 필터링
                    return availableHashtags.where((String option) {
                      return option
                          .toLowerCase()
                          .contains(textEditingValue.text.toLowerCase());
                    });
                  },
                  onSelected: (String selection) {
                    _addHashtag(selection);
                  },
                  fieldViewBuilder: (
                    BuildContext context,
                    TextEditingController fieldTextEditingController,
                    FocusNode fieldFocusNode,
                    VoidCallback onFieldSubmitted,
                  ) {
                    // 외부 controller와 동기화
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      fieldTextEditingController.text = _hashtagController.text;
                      fieldTextEditingController.selection =
                          _hashtagController.selection;
                    });

                    fieldTextEditingController.addListener(() {
                      _hashtagController.text = fieldTextEditingController.text;
                      _hashtagController.selection =
                          fieldTextEditingController.selection;
                    });

                    return Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: fieldTextEditingController,
                            focusNode: fieldFocusNode,
                            decoration: InputDecoration(
                              labelText: 'Hashtag',
                              hintText: 'Type to search existing hashtags',
                              suffixIcon: fieldTextEditingController
                                      .text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 20),
                                      onPressed: () {
                                        fieldTextEditingController.clear();
                                        _hashtagController.clear();
                                      },
                                    )
                                  : null,
                            ),
                            enabled: !_isSaving,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) {
                              _addHashtag(fieldTextEditingController.text);
                              onFieldSubmitted();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _isSaving
                              ? null
                              : () {
                                  _addHashtag(fieldTextEditingController.text);
                                  onFieldSubmitted();
                                },
                          child: const Text('Add'),
                        ),
                      ],
                    );
                  },
                  optionsViewBuilder: (
                    BuildContext context,
                    AutocompleteOnSelected<String> onSelected,
                    Iterable<String> options,
                  ) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4.0,
                        borderRadius: BorderRadius.circular(8),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxHeight: 200,
                            maxWidth: 300,
                          ),
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: options.length,
                            itemBuilder: (BuildContext context, int index) {
                              final String option = options.elementAt(index);
                              return InkWell(
                                onTap: () {
                                  onSelected(option);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: Colors.grey[200]!,
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.tag,
                                        size: 18,
                                        color: AppTheme.primaryColor,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '#$option',
                                        style: TextStyle(
                                          color: AppTheme.primaryColor,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 16),

            // 추가된 해시태그 목록
            if (_hashtags.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _hashtags.map((hashtag) {
                  return Chip(
                    label: Text('#$hashtag'),
                    onDeleted: _isSaving ? null : () => _removeHashtag(hashtag),
                    deleteIconColor: AppTheme.primaryColor,
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}
