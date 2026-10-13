import 'package:flutter/material.dart';

import '../theme.dart';

Future<void> showSuccessBottomSheet(
  BuildContext context, {
  required String title,
  required String message,
  String actionLabel = 'Continue',
}) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.forest.withValues(alpha: .5),
    builder: (sheetContext) => _SuccessBottomSheet(
      title: title,
      message: message,
      actionLabel: actionLabel,
    ),
  );
}

class _SuccessBottomSheet extends StatelessWidget {
  const _SuccessBottomSheet({
    required this.title,
    required this.message,
    required this.actionLabel,
  });

  final String title;
  final String message;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('success-bottom-sheet'),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 5,
            decoration: BoxDecoration(
              color: AppColors.line,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 16),
          Semantics(
            label: 'Success',
            image: true,
            child: Image.asset(
              'success.gif',
              key: const ValueKey('success-animation'),
              width: 132,
              height: 132,
              fit: BoxFit.contain,
              excludeFromSemantics: true,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          FilledButton(
            key: const ValueKey('success-sheet-action'),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
