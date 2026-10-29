import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/tokens.dart';

/// The Plate Focus mark: a plate (two concentric circles) inside four rounded focus corners,
/// with a small leaf as the organic detail. Below 28 px the leaf is dropped (guidelines §3).
class PlateFocusMark extends StatelessWidget {
  const PlateFocusMark({super.key, this.size = 32, this.color, this.detailColor});

  final double size;
  final Color? color;
  final Color? detailColor;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      label: 'MealLens',
      image: true,
      child: CustomPaint(
        size: Size.square(size),
        painter: PlateFocusPainter(
          ink: color ?? (dark ? GraphiteMint.text : MistEucalyptus.text),
          detail: detailColor ?? (dark ? GraphiteMint.accent : MistEucalyptus.accentStrong),
          showDetail: size >= 28,
        ),
      ),
    );
  }
}

/// Paints the mark; public so tool/render_brand_assets_test.dart can render the launch images.
class PlateFocusPainter extends CustomPainter {
  PlateFocusPainter({required this.ink, required this.detail, required this.showDetail});

  final Color ink;
  final Color detail;
  final bool showDetail;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final stroke = s * 0.07;
    final line = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final center = Offset(s / 2, s / 2);

    // Focus corners.
    final inset = stroke / 2;
    final arm = s * 0.2;
    final r = s * 0.1;
    for (final corner in [
      (Offset(inset, inset), 1.0, 1.0),
      (Offset(s - inset, inset), -1.0, 1.0),
      (Offset(inset, s - inset), 1.0, -1.0),
      (Offset(s - inset, s - inset), -1.0, -1.0),
    ]) {
      final (o, dx, dy) = corner;
      final path = Path()
        ..moveTo(o.dx, o.dy + dy * arm)
        ..lineTo(o.dx, o.dy + dy * r)
        ..quadraticBezierTo(o.dx, o.dy, o.dx + dx * r, o.dy)
        ..lineTo(o.dx + dx * arm, o.dy);
      canvas.drawPath(path, line);
    }

    // Plate rim and well.
    canvas.drawCircle(center, s * 0.29, line);
    canvas.drawCircle(center, s * 0.17, line..strokeWidth = stroke * 0.6);

    if (showDetail) {
      // A leaf resting on the rim, upper right.
      final leaf = Path();
      final base = center + Offset.fromDirection(-math.pi / 4, s * 0.29);
      final tip = base + Offset.fromDirection(-math.pi / 4, s * 0.14);
      final mid = Offset.lerp(base, tip, 0.5)!;
      final normal = Offset.fromDirection(math.pi / 4, s * 0.06);
      leaf
        ..moveTo(base.dx, base.dy)
        ..quadraticBezierTo((mid + normal).dx, (mid + normal).dy, tip.dx, tip.dy)
        ..quadraticBezierTo((mid - normal).dx, (mid - normal).dy, base.dx, base.dy)
        ..close();
      canvas.drawPath(leaf, Paint()..color = detail);
    }
  }

  @override
  bool shouldRepaint(PlateFocusPainter old) => old.ink != ink || old.detail != detail || old.showDetail != showDetail;
}

/// Horizontal lockup: mark to the left of the "MealLens" wordmark in Nunito Sans Medium.
class MealLensLogo extends StatelessWidget {
  const MealLensLogo({super.key, this.markSize = 32});

  final double markSize;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PlateFocusMark(size: markSize),
        SizedBox(width: markSize * 0.35),
        Text(
          'MealLens',
          // The wordmark is part of the logo: it keeps its proportions to the mark at any text size.
          textScaler: TextScaler.noScaling,
          style: GoogleFonts.nunitoSans(
            fontSize: markSize * 0.78,
            fontWeight: FontWeight.w500,
            color: dark ? GraphiteMint.text : MistEucalyptus.text,
            height: 1,
          ),
        ),
      ],
    );
  }
}
