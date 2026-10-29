import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/logo.dart';

/// Shown while the app starts. It continues the native launch screen (the mark on the brand
/// background), and the wordmark fades in below the mark. No spinner unless start-up is slow.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.slow = false});

  /// True once start-up has taken long enough that a quiet progress line is reassuring.
  final bool slow;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final ink = dark ? GraphiteMint.text : MistEucalyptus.text;
    final muted = dark ? GraphiteMint.textMuted : MistEucalyptus.accentStrong;
    return Material(
      color: dark ? GraphiteMint.background : MistEucalyptus.background,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PlateFocusMark(size: 96),
            const SizedBox(height: Space.xl),
            AnimatedOpacity(
              opacity: _shown ? 1 : 0,
              duration: motion(context, const Duration(milliseconds: 450)),
              curve: Curves.easeOut,
              child: Column(children: [
                Text('MealLens', style: GoogleFonts.nunitoSans(fontSize: 28, fontWeight: FontWeight.w500, color: ink, height: 1.2)),
                const SizedBox(height: Space.xs),
                Text('Calm kitchen intelligence', style: GoogleFonts.nunitoSans(fontSize: 14, color: muted)),
              ]),
            ),
            const SizedBox(height: Space.xxl),
            SizedBox(
              width: 120,
              height: 2,
              child: AnimatedOpacity(
                opacity: widget.slow ? 1 : 0,
                duration: motion(context, const Duration(milliseconds: 300)),
                child: widget.slow
                    ? LinearProgressIndicator(minHeight: 2, color: muted, backgroundColor: muted.withValues(alpha: 0.2))
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
