import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import '../../../core/widget/responseive_container.dart';
import '../providers/ref_provider.dart';
import '../../groups/providers/group_provider.dart';
import '../../../shared/models/ref.dart';
import '../../../core/theme/app_theme.dart';

class RefFormScreen extends StatefulWidget {
  final Ref? ref;

  const RefFormScreen({super.key, this.ref});

  @override
  State<RefFormScreen> createState() => _RefFormScreenState();
}

class _RefFormScreenState extends State<RefFormScreen> {
  static const int _maxSummaries = 3;

  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final List<TextEditingController> _summaryControllers;
  late final TextEditingController _contentController;
  final _hashtagController = TextEditingController();

  final _titleFocusNode = FocusNode();
  late final List<FocusNode> _summaryFocusNodes;
  final _contentFocusNode = FocusNode();
  final _hashtagFocusNode = FocusNode();

  late List<String> _hashtags;
  late int? _selectedGroupId;
  bool _isSaving = false;

  bool get _isEditMode => widget.ref != null;
  bool get _canAddSummary => _summaryControllers.length < _maxSummaries;

  @override
  void initState() {
    super.initState();

    _titleController = TextEditingController(text: widget.ref?.title ?? '');
    _contentController = TextEditingController(text: widget.ref?.content ?? '');
    _hashtags = widget.ref?.hashtags.map((t) => t.name).toList() ?? [];
    _selectedGroupId = widget.ref?.groupId;

    // Initialize summary controllers — at least 1 empty field
    final initialSummaries = (widget.ref?.summaries.isNotEmpty == true)
        ? widget.ref!.summaries
        : [''];
    _summaryControllers =
        initialSummaries.map((s) => TextEditingController(text: s)).toList();
    _summaryFocusNodes =
        List.generate(_summaryControllers.length, (_) => FocusNode());
  }

  @override
  void dispose() {
    _titleController.dispose();
    for (final c in _summaryControllers) c.dispose();
    for (final n in _summaryFocusNodes) n.dispose();
    _contentController.dispose();
    _hashtagController.dispose();
    _titleFocusNode.dispose();
    _contentFocusNode.dispose();
    _hashtagFocusNode.dispose();
    super.dispose();
  }

  // ── Summary management ────────────────────────────────────────────────────

  void _addSummary() {
    if (!_canAddSummary) return;
    setState(() {
      _summaryControllers.add(TextEditingController());
      _summaryFocusNodes.add(FocusNode());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _summaryFocusNodes.last.requestFocus();
    });
  }

  void _removeSummary(int index) {
    setState(() {
      _summaryControllers[index].dispose();
      _summaryFocusNodes[index].dispose();
      _summaryControllers.removeAt(index);
      _summaryFocusNodes.removeAt(index);
      // Always keep at least one field
      if (_summaryControllers.isEmpty) {
        _summaryControllers.add(TextEditingController());
        _summaryFocusNodes.add(FocusNode());
      }
    });
  }

  List<String> _collectSummaries() => _summaryControllers
      .map((c) => c.text.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final title = _titleController.text.trim();
    final summaries = _collectSummaries();
    final content = _contentController.text.trim();

    final provider = context.read<RefProvider>();
    bool success;

    if (_isEditMode) {
      success = await provider.updateRef(
        id: widget.ref!.id,
        title: title,
        summaries: summaries,
        content: content.isEmpty ? null : content,
        groupId: _selectedGroupId ?? 0,
        hashtags: _hashtags,
      );
    } else {
      success = await provider.createRef(
        title: title,
        summaries: summaries,
        content: content.isEmpty ? null : content,
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
            content: Text(provider.error ?? 'Save failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ── Hashtag helpers ───────────────────────────────────────────────────────

  void _addHashtag(String raw) {
    final tag = raw.trim().toLowerCase().replaceAll(RegExp(r'^#+'), '');
    if (tag.isEmpty || _hashtags.contains(tag)) {
      _hashtagController.clear();
      return;
    }
    setState(() => _hashtags.add(tag));
    _hashtagController.clear();
  }

  void _removeHashtag(String tag) => setState(() => _hashtags.remove(tag));

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Reference' : 'New Reference'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text('Save',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: ResponsiveContainer.paddingOf(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Group picker ───────────────────────────────────────────────
              Consumer<GroupProvider>(
                builder: (context, groupProvider, _) {
                  final flatGroups = groupProvider.getFlatGroupList();
                  return DropdownButtonFormField2<int?>(
                    value: _selectedGroupId,
                    decoration: const InputDecoration(labelText: 'Group'),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('No Group',
                            style: TextStyle(color: Colors.grey)),
                      ),
                      ...flatGroups.map((g) {
                        final depth = groupProvider.getGroupDepth(g.id);
                        final prefix = '    ' * (depth < 0 ? 0 : depth);
                        return DropdownMenuItem<int?>(
                          value: g.id,
                          child: Text('$prefix${g.name}'),
                        );
                      }),
                    ],
                    onChanged: _isSaving
                        ? null
                        : (v) => setState(() => _selectedGroupId = v),
                  );
                },
              ),
              const SizedBox(height: 16),

              // ── Title ──────────────────────────────────────────────────────
              Focus(
                onKeyEvent: (_, event) {
                  if (event is KeyDownEvent &&
                      event.logicalKey == LogicalKeyboardKey.tab &&
                      !HardwareKeyboard.instance.isShiftPressed) {
                    _summaryFocusNodes.first.requestFocus();
                    return KeyEventResult.handled;
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
                  onFieldSubmitted: (_) =>
                      _summaryFocusNodes.first.requestFocus(),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Please enter a title'
                      : null,
                ),
              ),
              const SizedBox(height: 16),

              // ── Summaries ──────────────────────────────────────────────────
              _buildSummariesSection(),
              const SizedBox(height: 16),

              // ── Content ────────────────────────────────────────────────────
              Focus(
                onKeyEvent: (_, event) {
                  if (event is KeyDownEvent &&
                      event.logicalKey == LogicalKeyboardKey.tab) {
                    if (HardwareKeyboard.instance.isShiftPressed) {
                      _summaryFocusNodes.last.requestFocus();
                    } else {
                      _hashtagFocusNode.requestFocus();
                    }
                    return KeyEventResult.handled;
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

              // ── Hashtags ───────────────────────────────────────────────────
              _buildHashtagSection(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummariesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Summaries',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
            const SizedBox(width: 4),
            Text(
              '(${_summaryControllers.length}/$_maxSummaries)',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...List.generate(_summaryControllers.length, (i) {
          final isLast = i == _summaryControllers.length - 1;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Focus(
              onKeyEvent: (_, event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.tab) {
                  if (HardwareKeyboard.instance.isShiftPressed) {
                    if (i == 0) {
                      _titleFocusNode.requestFocus();
                    } else {
                      _summaryFocusNodes[i - 1].requestFocus();
                    }
                  } else {
                    if (isLast) {
                      _contentFocusNode.requestFocus();
                    } else {
                      _summaryFocusNodes[i + 1].requestFocus();
                    }
                  }
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _summaryControllers[i],
                      focusNode: _summaryFocusNodes[i],
                      decoration: InputDecoration(
                        labelText: 'Summary ${i + 1}',
                        hintText: 'Brief summary for card view',
                      ),
                      enabled: !_isSaving,
                      minLines: 1,
                      maxLines: 3,
                      textInputAction: TextInputAction.newline,
                      onFieldSubmitted: (_) {
                        if (isLast) {
                          _contentFocusNode.requestFocus();
                        } else {
                          _summaryFocusNodes[i + 1].requestFocus();
                        }
                      },
                    ),
                  ),
                  // Show remove button if more than 1 field OR if this is a filled extra field
                  if (_summaryControllers.length > 1)
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      color: Colors.grey,
                      tooltip: 'Remove summary',
                      onPressed: _isSaving ? null : () => _removeSummary(i),
                    ),
                ],
              ),
            ),
          );
        }),
        if (_canAddSummary)
          TextButton.icon(
            onPressed: _isSaving ? null : _addSummary,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Summary'),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
              padding: EdgeInsets.zero,
            ),
          ),
      ],
    );
  }

  Widget _buildHashtagSection() {
    return Consumer<RefProvider>(
      builder: (context, refProvider, _) {
        final available =
            refProvider.hashtags.where((t) => !_hashtags.contains(t)).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Autocomplete<String>(
              optionsBuilder: (value) => value.text.isEmpty
                  ? const []
                  : available.where((o) =>
                      o.toLowerCase().contains(value.text.toLowerCase())),
              onSelected: _addHashtag,
              fieldViewBuilder: (ctx, ctrl, focusNode, _) {
                _hashtagController.addListener(() {
                  if (ctrl.text != _hashtagController.text) {
                    ctrl.text = _hashtagController.text;
                  }
                });
                return Focus(
                  onKeyEvent: (_, event) {
                    if (event is KeyDownEvent &&
                        event.logicalKey == LogicalKeyboardKey.tab &&
                        HardwareKeyboard.instance.isShiftPressed) {
                      _contentFocusNode.requestFocus();
                      return KeyEventResult.handled;
                    }
                    if (event is KeyDownEvent &&
                        event.logicalKey == LogicalKeyboardKey.enter) {
                      _addHashtag(ctrl.text);
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: TextFormField(
                    controller: ctrl,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      labelText: 'Hashtags',
                      hintText: 'Type and press Enter',
                      prefixText: '#',
                    ),
                    enabled: !_isSaving,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: _addHashtag,
                  ),
                );
              },
            ),
            if (_hashtags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _hashtags
                    .map(
                      (tag) => Chip(
                        label: Text('#$tag'),
                        onDeleted: _isSaving ? null : () => _removeHashtag(tag),
                        deleteIconColor: Colors.grey,
                        backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                        labelStyle: TextStyle(color: AppTheme.primaryColor),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        );
      },
    );
  }
}
