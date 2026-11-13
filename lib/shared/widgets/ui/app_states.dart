import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:pushtrial/shared/widgets/ui/app_spacing.dart';
import 'package:pushtrial/shared/widgets/ui/app_tokens.dart';

/// Round icon well shared by the empty and error states.
class _IconWell extends StatelessWidget {
  const _IconWell({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ShadTheme.of(context).colorScheme.muted,
      ),
      child: Icon(icon, size: 32, color: color),
    );
  }
}

/// Centered message for "nothing here yet".
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = LucideIcons.inbox,
  });

  final String title;
  final String? message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _IconWell(icon: icon, color: theme.colorScheme.mutedForeground),
            Gap.hLg,
            Text(title, style: theme.textTheme.large, textAlign: TextAlign.center),
            if (message != null) ...[
              Gap.hXs,
              Text(message!, style: theme.textTheme.muted, textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}

/// Centered error with a Retry button.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    this.title = 'Something went wrong',
    this.message = 'Check your connection and try again.',
    this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _IconWell(icon: LucideIcons.circleAlert, color: theme.colorScheme.destructive),
            Gap.hLg,
            Text(title, style: theme.textTheme.large, textAlign: TextAlign.center),
            Gap.hXs,
            Text(message, style: theme.textTheme.muted, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              Gap.hLg,
              ShadButton.outline(
                onPressed: onRetry,
                leading: const Icon(LucideIcons.refreshCw, size: IconSize.inline),
                child: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Pulsing placeholder block. Use a few of them instead of a spinner while a page loads.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({super.key, this.height = 16, this.width, this.radius = 8});

  final double height;
  final double? width;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: AppMotion.pulse,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion: a still placeholder instead of a pulse.
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
      _c.value = 1;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final muted = ShadTheme.of(context).colorScheme.muted;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Opacity(
        opacity: 0.5 + 0.5 * _c.value,
        child: Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            color: muted,
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        ),
      ),
    );
  }
}

/// Page-sized loading placeholder: a title line and a few card blocks.
class LoadingSkeleton extends StatelessWidget {
  const LoadingSkeleton({super.key, this.cards = 3});

  final int cards;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: Gap.pageAll,
      children: [
        const SkeletonBox(height: 24, width: 160),
        Gap.hLg,
        for (var i = 0; i < cards; i++) ...[
          const SkeletonBox(height: 96, radius: AppRadius.row),
          Gap.hMd,
        ],
      ],
    );
  }
}
