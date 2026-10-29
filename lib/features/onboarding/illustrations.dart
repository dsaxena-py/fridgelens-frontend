import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../widgets/logo.dart';

/// Restrained editorial illustrations for onboarding (guidelines §8): rounded geometric forms,
/// flat fills from the brand palette, generous negative space. No faces, no mascots.
class OnboardingIllustration extends StatelessWidget {
  const OnboardingIllustration({super.key, required this.page});

  final int page;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final palette = _Palette(dark);
    return AspectRatio(
      aspectRatio: 1,
      child: ExcludeSemantics(
        child: switch (page) {
          0 => _PlateScene(palette: palette),
          1 => CustomPaint(painter: _ScanScenePainter(palette)),
          _ => _MatchScene(palette: palette),
        },
      ),
    );
  }
}

class _Palette {
  _Palette(bool dark)
      : disc = dark ? GraphiteMint.surface : MistEucalyptus.surface,
        soft = dark ? GraphiteMint.surfaceElevated : const Color(0xFFC9D5CC),
        accent = dark ? GraphiteMint.accent : MistEucalyptus.accent,
        strong = dark ? GraphiteMint.accent : MistEucalyptus.accentStrong,
        ink = dark ? GraphiteMint.text : MistEucalyptus.text,
        produce = [StatusColors.success, StatusColors.attention, StatusColors.error.withValues(alpha: 0.85)];

  final Color disc, soft, accent, strong, ink;
  final List<Color> produce;
}

/// Page 1: the Plate Focus mark on a large soft disc, with a few ingredients around it.
class _PlateScene extends StatelessWidget {
  const _PlateScene({required this.palette});

  final _Palette palette;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final s = c.maxWidth;
        return Stack(alignment: Alignment.center, children: [
          Container(width: s * 0.86, height: s * 0.86, decoration: BoxDecoration(color: palette.disc, shape: BoxShape.circle)),
          CustomPaint(size: Size.square(s), painter: _ProducePainter(palette)),
          PlateFocusMark(size: s * 0.36),
        ]);
      });
}

class _ProducePainter extends CustomPainter {
  _ProducePainter(this.p);

  final _Palette p;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final c = Offset(s / 2, s / 2);
    // Round produce placed around the plate, like an overhead shot with negative space.
    final items = [
      (-2.4, 0.36, 0.075, p.produce[2]), // tomato
      (-0.75, 0.37, 0.06, p.produce[1]), // lemon
      (0.55, 0.36, 0.085, p.produce[0]), // greens
      (2.2, 0.35, 0.05, p.accent), // egg-ish
    ];
    for (final (angle, dist, r, color) in items) {
      final o = c + Offset.fromDirection(angle, s * dist);
      canvas.drawCircle(o, s * r, Paint()..color = color);
    }
    // A leaf near the greens.
    final leafBase = c + Offset.fromDirection(0.9, s * 0.30);
    final tip = leafBase + Offset.fromDirection(0.2, s * 0.11);
    final mid = Offset.lerp(leafBase, tip, 0.5)!;
    final n = Offset.fromDirection(0.2 + math.pi / 2, s * 0.035);
    canvas.drawPath(
      Path()
        ..moveTo(leafBase.dx, leafBase.dy)
        ..quadraticBezierTo((mid + n).dx, (mid + n).dy, tip.dx, tip.dy)
        ..quadraticBezierTo((mid - n).dx, (mid - n).dy, leafBase.dx, leafBase.dy),
      Paint()..color = p.strong,
    );
  }

  @override
  bool shouldRepaint(_ProducePainter old) => false;
}

/// Page 2: a shelf of simple shapes inside four scan corners, two of them boxed.
class _ScanScenePainter extends CustomPainter {
  _ScanScenePainter(this.p);

  final _Palette p;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final bg = RRect.fromRectAndRadius(Rect.fromLTWH(s * 0.08, s * 0.1, s * 0.84, s * 0.8), Radius.circular(s * 0.08));
    canvas.drawRRect(bg, Paint()..color = p.disc);
    // Shelf line.
    canvas.drawLine(Offset(s * 0.16, s * 0.66), Offset(s * 0.84, s * 0.66),
        Paint()
          ..color = p.soft
          ..strokeWidth = s * 0.018
          ..strokeCap = StrokeCap.round);
    // Items on the shelf: carton, round fruit, jar.
    final carton = RRect.fromRectAndRadius(Rect.fromLTWH(s * 0.22, s * 0.36, s * 0.14, s * 0.28), Radius.circular(s * 0.025));
    canvas.drawRRect(carton, Paint()..color = p.accent);
    canvas.drawCircle(Offset(s * 0.5, s * 0.565), s * 0.08, Paint()..color = p.produce[2]);
    final jar = RRect.fromRectAndRadius(Rect.fromLTWH(s * 0.64, s * 0.46, s * 0.13, s * 0.18), Radius.circular(s * 0.03));
    canvas.drawRRect(jar, Paint()..color = p.soft);

    // Detection boxes around the carton and the fruit (the jar is not an ingredient).
    final box = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.012;
    canvas.drawRRect(carton.inflate(s * 0.025), box..color = StatusColors.success);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCircle(center: Offset(s * 0.5, s * 0.565), radius: s * 0.105), Radius.circular(s * 0.03)),
      box..color = StatusColors.attention,
    );

    // Scan corners.
    final corner = Paint()
      ..color = p.strong
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.014
      ..strokeCap = StrokeCap.round;
    final r = Rect.fromLTWH(s * 0.14, s * 0.18, s * 0.72, s * 0.64);
    final arm = s * 0.09, rad = s * 0.04;
    for (final (o, sx, sy) in [(r.topLeft, 1.0, 1.0), (r.topRight, -1.0, 1.0), (r.bottomLeft, 1.0, -1.0), (r.bottomRight, -1.0, -1.0)]) {
      canvas.drawPath(
        Path()
          ..moveTo(o.dx, o.dy + sy * arm)
          ..lineTo(o.dx, o.dy + sy * rad)
          ..quadraticBezierTo(o.dx, o.dy, o.dx + sx * rad, o.dy)
          ..lineTo(o.dx + sx * arm, o.dy),
        corner,
      );
    }
  }

  @override
  bool shouldRepaint(_ScanScenePainter old) => false;
}

/// Page 3: a circular ingredient-match indicator with the number written out.
class _MatchScene extends StatelessWidget {
  const _MatchScene({required this.palette});

  final _Palette palette;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final s = c.maxWidth;
        final theme = Theme.of(context);
        return Stack(alignment: Alignment.center, children: [
          Container(width: s * 0.86, height: s * 0.86, decoration: BoxDecoration(color: palette.disc, shape: BoxShape.circle)),
          SizedBox.square(
            dimension: s * 0.56,
            child: CustomPaint(painter: _RingPainter(palette, 0.83)),
          ),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text('5 of 6', style: theme.textTheme.headlineMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
            Text('ingredients', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ]),
        ]);
      });
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.p, this.value);

  final _Palette p;
  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.08;
    final rect = Offset.zero & size;
    final track = Paint()
      ..color = p.soft
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final arc = Paint()
      ..color = p.strong
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect.deflate(stroke / 2), 0, math.pi * 2, false, track);
    canvas.drawArc(rect.deflate(stroke / 2), -math.pi / 2, math.pi * 2 * value, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value;
}
