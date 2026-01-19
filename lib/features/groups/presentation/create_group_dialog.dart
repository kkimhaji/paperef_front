import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/group_provider.dart';

class CreateGroupDialog extends StatefulWidget {
  final int? parentId; // 부모 그룹 ID

  const CreateGroupDialog({super.key, this.parentId});

  @override
  State<CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<CreateGroupDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  int? _selectedParentId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedParentId = widget.parentId;

    // 트리 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GroupProvider>().fetchGroupTree();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createGroup() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final success = await context.read<GroupProvider>().createGroup(
            name: _nameController.text.trim(),
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            parentId: _selectedParentId,
          );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (success) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Group created successfully')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.read<GroupProvider>().error ??
                  'Failed to create group'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
          widget.parentId == null ? 'Create New Group' : 'Create Subgroup'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 부모 그룹 선택
              if (widget.parentId == null)
                Consumer<GroupProvider>(
                  builder: (context, groupProvider, _) {
                    final flatGroups = groupProvider.getFlatGroupList();

                    return DropdownButtonFormField<int?>(
                      value: _selectedParentId,
                      decoration: const InputDecoration(
                        labelText: 'Parent Group (Optional)',
                        hintText: 'Select parent group',
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('None (Root Level)'),
                        ),
                        ...flatGroups.map((group) {
                          final depth = groupProvider.getGroupDepth(group.id);
                          final indent = '  ' * depth;
                          return DropdownMenuItem<int?>(
                            value: group.id,
                            child: Text('$indent${group.name}'),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedParentId = value;
                        });
                      },
                    );
                  },
                ),
              if (widget.parentId == null) const SizedBox(height: 16),

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Group Name *',
                  hintText: 'e.g., Research Papers',
                ),
                enabled: !_isLoading,
                autofocus: true,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a group name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  hintText: 'Brief description of this group',
                ),
                enabled: !_isLoading,
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _createGroup,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}
