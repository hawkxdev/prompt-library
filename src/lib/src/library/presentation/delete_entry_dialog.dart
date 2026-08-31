/// Entry deletion confirmation.
library;

import 'package:flutter/material.dart';

import '../models/entry.dart';

/// Confirms physical entry deletion.
Future<bool> showDeleteEntryDialog(
  BuildContext context, {
  required Entry entry,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete prompt?'),
          content: Text('“${entry.title}” will be permanently deleted.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      ) ??
      false;
}
