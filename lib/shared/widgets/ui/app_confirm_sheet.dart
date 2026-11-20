import 'package:pushtrial/core/config/app_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:pushtrial/shared/widgets/ui/app_spacing.dart';
import 'package:pushtrial/shared/widgets/ui/app_tokens.dart';

/// App-wide bottom sheets that replace pop-up dialogs. Both share one look (the same as the school
/// finder): rounded top corners, drag handle, app background, tinted icon badge, pill buttons.
///
/// - [showConfirmSheet]: a yes/no question.
/// - [showNoticeSheet]: a message or details with a single button.

/// Asks the user to confirm an action. Returns true only when they pick the confirm button;
/// Cancel, the back button, a swipe down and a tap outside all return false.
Future<bool> showConfirmSheet(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  IconData icon = LucideIcons.triangleAlert,
  bool destructive = false,
}) async {
  final result = await _openSheet(
    context,
    (sheetContext) => _SheetBody(
      title: title,
      message: message,
      icon: icon,
      destructive: destructive,
      primaryLabel: confirmLabel,
      onPrimary: () {
        if (destructive) HapticFeedback.mediumImpact();
        Navigator.of(sheetContext).pop(true);
      },
      secondaryLabel: cancelLabel,
      onSecondary: () => Navigator.of(sheetContext).pop(false),
    ),
  );
  return result ?? false;
}

/// Shows a message (an error, a heads-up, some details) with one button. Returns true when they
/// press the button, false when they dismiss it another way. Pass [child] for richer content,
/// such as a list of event details, shown under the message.
Future<bool> showNoticeSheet(
  BuildContext context, {
  required String title,
  String? message,
  Widget? child,
  String buttonLabel = 'OK',
  IconData icon = LucideIcons.info,
  bool error = false,
}) async {
  final result = await _openSheet(
    context,
    (sheetContext) => _SheetBody(
      title: title,
      message: message,
      content: child,
      icon: icon,
      destructive: error,
      // An error notice gets a red badge but a neutral button: dismissing it is not a risky action.
      destructiveButton: false,
      primaryLabel: buttonLabel,
      onPrimary: () => Navigator.of(sheetContext).pop(true),
    ),
  );
  return result ?? false;
}

Future<bool?> _openSheet(BuildContext context, WidgetBuilder builder) {
  HapticFeedback.selectionClick();
  return showModalBottomSheet<bool>(
    context: context,
    sheetAnimationStyle: AppTransitions.sheet,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 480),
    backgroundColor: ShadTheme.of(context).colorScheme.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
    ),
    builder: builder,
  );
}

class _SheetBody extends StatelessWidget {
  const _SheetBody({
    required this.title,
    required this.icon,
    required this.destructive,
    required this.primaryLabel,
    required this.onPrimary,
    this.destructiveButton,
    this.message,
    this.content,
    this.secondaryLabel,
    this.onSecondary,
  });

  /// Whether the main button is red. Defaults to [destructive].
  final bool? destructiveButton;

  final String title;
  final String? message;
  final Widget? content;
  final IconData icon;
  final bool destructive;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    // Red only for a destructive confirmation (log out) or an error notice. The badge is a neutral
    // gray otherwise, and the main button stays the neutral primary unless the action is destructive.
    final badgeColor = destructive ? scheme.destructive : scheme.foreground;
    final badgeFill = destructive
        ? scheme.destructive.withValues(alpha: 0.12)
        : scheme.muted;
    final pill = ShadDecoration(
      border: ShadBorder.all(radius: BorderRadius.circular(AppRadius.pill)),
    );
    // Off-gray fill so the secondary button reads as a button in both light and dark mode.
    final grayFill = Color.alphaBlend(
      scheme.foreground.withValues(alpha: 0.08),
      scheme.background,
    );
    final grayHover = Color.alphaBlend(
      scheme.foreground.withValues(alpha: 0.14),
      scheme.background,
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.xs, Gap.xl, Gap.lg),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: ExcludeSemantics(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: badgeFill,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: IconSize.nav + 4, color: badgeColor),
                  ),
                ),
              ),
              Gap.hLg,
              Semantics(
                header: true,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.h4.copyWith(color: scheme.foreground),
                ),
              ),
              if (message != null && message!.isNotEmpty) ...[
                Gap.hSm,
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.muted,
                ),
              ],
              if (content != null) ...[Gap.hLg, content!],
              Gap.hXl,
              (destructiveButton ?? destructive)
                  ? ShadButton.destructive(
                      onPressed: onPrimary,
                      height: kMinTap + 8,
                      decoration: pill,
                      child: Text(primaryLabel),
                    )
                  : ShadButton(
                      onPressed: onPrimary,
                      height: kMinTap + 8,
                      decoration: pill,
                      child: Text(primaryLabel),
                    ),
              if (secondaryLabel != null) ...[
                Gap.hSm,
                ShadButton.secondary(
                  onPressed: onSecondary,
                  height: kMinTap + 8,
                  backgroundColor: grayFill,
                  hoverBackgroundColor: grayHover,
                  pressedBackgroundColor: grayHover,
                  foregroundColor: scheme.foreground,
                  decoration: pill,
                  child: Text(secondaryLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
