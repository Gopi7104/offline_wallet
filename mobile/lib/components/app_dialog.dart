import 'package:flutter/material.dart';
import 'package:offline_wallet/theme/theme.dart';

/// Themed confirm dialog helper. Returns true only if the confirm action was
/// tapped (styling comes from the global `DialogThemeData`).
Future<bool> showAppConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool danger = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(cancelLabel)),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            confirmLabel,
            style: TextStyle(color: danger ? AppColors.error : AppColors.accent, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Themed info dialog helper — single dismiss action.
Future<void> showAppInfoDialog(
  BuildContext context, {
  required String title,
  required String message,
  String dismissLabel = 'OK',
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(dismissLabel)),
      ],
    ),
  );
}
