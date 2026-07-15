import 'package:flutter/material.dart';
import 'package:offline_wallet/theme/theme.dart';

/// Themed modal bottom sheet helper (styling comes from the global
/// `BottomSheetThemeData` set in `AppTheme`).
Future<T?> showAppBottomSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isDismissible = true,
  bool isScrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isDismissible: isDismissible,
    isScrollControlled: isScrollControlled,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.l, AppSpacing.xl, AppSpacing.xl),
        child: builder(context),
      ),
    ),
  );
}
