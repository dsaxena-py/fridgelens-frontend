import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// An inline message with an icon: errors and notices are never shown by colour alone (§11).
class InlineBanner extends StatelessWidget {
  const InlineBanner({super.key, required this.text, this.isError = false});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? StatusColors.error : StatusColors.info;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(Space.md),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(Radii.control)),
        child: Row(children: [
          Icon(isError ? Icons.error_outline_rounded : Icons.mark_email_unread_outlined, color: color, size: 20),
          const SizedBox(width: Space.md),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
        ]),
      ),
    );
  }
}

/// Motion that respects the system's reduce-motion setting (§12).
Duration motion(BuildContext context, Duration d) => MediaQuery.of(context).disableAnimations ? Duration.zero : d;
