import 'package:flutter/cupertino.dart';
import 'package:sanovault/theme/sv_colors.dart';

class SvFilledButton extends StatelessWidget {
  const SvFilledButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      color: SvColors.coral,
      disabledColor: SvColors.coral.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onPressed: enabled ? onPressed : null,
      child: Text(
        label,
        style: const TextStyle(
          color: CupertinoColors.white,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class SvErrorBanner extends StatelessWidget {
  const SvErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE5E5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: const TextStyle(color: SvColors.danger, fontSize: 16),
      ),
    );
  }
}

class SvCard extends StatelessWidget {
  const SvCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: SvColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SvColors.separator.withValues(alpha: 0.6)),
      ),
      child: child,
    );
  }
}
