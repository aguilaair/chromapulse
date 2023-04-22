import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class SettingEditDialog extends StatefulHookConsumerWidget {
  const SettingEditDialog({
    super.key,
    required this.title,
    required this.onSave,
    required this.initialValue,
  });

  final String title;
  final Function(String) onSave;
  final String initialValue;

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _SettingEditDialogState();
}

class _SettingEditDialogState extends ConsumerState<SettingEditDialog> {
  @override
  Widget build(BuildContext context) {
    final controller = useTextEditingController(text: widget.initialValue);

    return AlertDialog(
      icon: const Icon(Icons.settings),
      title: Text(widget.title),
      content: TextField(
        controller: controller,
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: widget.title,
        ),
        onSubmitted: (value) {
          widget.onSave(value);
          Navigator.of(context).pop();
        },
      ),
      actions: [
        TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text("Cancel")),
        TextButton(
          onPressed: () {
            widget.onSave(controller.text);
            Navigator.of(context).pop();
          },
          child: const Text("Save"),
        ),
      ],
    );
  }
}
