import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/group_provider.dart';
import '../../../features/refs/providers/ref_provider.dart';
import '../../../shared/models/group.dart';
import '../../../core/theme/app_theme.dart';

enum DeleteOption {
  moveToUngrouped,
  deleteRefs,
}

class DeleteGroupDialog extends StatefulWidget {
  final Group group;

  const DeleteGroupDialog({
    super.key,
    required this.group,
  });

  @override
  State<DeleteGroupDialog> createState() => _DeleteGroupDialogState();
}

class _DeleteGroupDialogState extends State<DeleteGroupDialog> {
  DeleteOption _selectedOption = DeleteOption.moveToUngrouped;
  bool _isDeleting = false;
  bool _isLoadingRefCount = true;
  int _totalRefCount = 0;
  bool _hasSubgroups = false;

  @override
  void initState() {
    super.initState();
    _loadRefCount();
  }

  Future<void> _loadRefCount() async {
    final groupProvider = context.read<GroupProvider>();
    final refCountData = await groupProvider.getGroupRefCount(
      widget.group.id,
      includeSubgroups: true,
    );

    if (mounted && refCountData != null) {
      setState(() {
        _totalRefCount = refCountData['ref_count'] as int;
        _hasSubgroups = refCountData['has_subgroups'] as bool;
        _isLoadingRefCount = false;
      });
    } else if (mounted) {
      setState(() {
        _isLoadingRefCount = false;
      });
    }
  }

  Future<void> _deleteGroup() async {
    setState(() => _isDeleting = true);

    final deleteRefs = _selectedOption == DeleteOption.deleteRefs;

    final success = await context.read<GroupProvider>().deleteGroup(
          widget.group.id,
          deleteRefs: deleteRefs,
        );

    if (mounted) {
      setState(() => _isDeleting = false);

      if (success) {
        // 레퍼런스 리스트 새로고침
        final groupProvider = context.read<GroupProvider>();
        final refProvider = context.read<RefProvider>();

        final currentGroupId = groupProvider.selectedGroupId;

        await refProvider.fetchRefs(
          groupId: currentGroupId,
          hashtag: refProvider.selectedHashtag,
          search: refProvider.searchQuery,
        );

        await refProvider.fetchHashtags();

        if (mounted) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                deleteRefs
                    ? 'Group and all references deleted successfully'
                    : 'Group deleted. References moved to ungrouped.',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete group'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange[700]),
          const SizedBox(width: 12),
          const Expanded(child: Text('Delete Group')),
        ],
      ),
      content: _isLoadingRefCount
          ? const Padding(
              padding: EdgeInsets.all(24.0),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Are you sure you want to delete "${widget.group.name}"?',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  if (_hasSubgroups) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: Colors.orange[700], size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'This will also delete all subgroups.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.orange[900],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_totalRefCount > 0) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.folder_open,
                              color: Colors.blue[700], size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _hasSubgroups
                                  ? 'This group and its subgroups contain $_totalRefCount reference(s) in total.'
                                  : 'This group contains $_totalRefCount reference(s).',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue[900],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'What would you like to do with the references?',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 12),
                    // 라디오 버튼 옵션들
                    RadioListTile<DeleteOption>(
                      value: DeleteOption.moveToUngrouped,
                      groupValue: _selectedOption,
                      onChanged: _isDeleting
                          ? null
                          : (value) {
                              setState(() => _selectedOption = value!);
                            },
                      title: const Text('Move to Ungrouped'),
                      subtitle: const Text(
                        'Keep all references but remove from groups',
                        style: TextStyle(fontSize: 12),
                      ),
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppTheme.primaryColor,
                    ),
                    RadioListTile<DeleteOption>(
                      value: DeleteOption.deleteRefs,
                      groupValue: _selectedOption,
                      onChanged: _isDeleting
                          ? null
                          : (value) {
                              setState(() => _selectedOption = value!);
                            },
                      title: const Text('Delete All References'),
                      subtitle: Text(
                        'Permanently delete all $_totalRefCount reference(s)',
                        style: const TextStyle(fontSize: 12, color: Colors.red),
                      ),
                      contentPadding: EdgeInsets.zero,
                      activeColor: Colors.red,
                    ),
                  ] else ...[
                    const SizedBox(height: 12),
                    Text(
                      _hasSubgroups
                          ? 'This group and its subgroups have no references.'
                          : 'This group has no references.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ],
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: _isDeleting || _isLoadingRefCount
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isDeleting || _isLoadingRefCount ? null : _deleteGroup,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red,
          ),
          child: _isDeleting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Delete'),
        ),
      ],
    );
  }
}
