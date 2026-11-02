import 'package:flutter/material.dart';

import '../data/models.dart';
import '../theme/tokens.dart';

/// Four thin rounded corner markers instead of a full border (guidelines §7).
class ScanFrame extends StatelessWidget {
  const ScanFrame({super.key, this.color = GraphiteMint.accent, this.inset = 0});

  final Color color;

  /// 0 = full size; the camera screen eases this from 0.06 to 0 when the camera is ready.
  final double inset;

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _FramePainter(color, inset), child: const SizedBox.expand());
}

class _FramePainter extends CustomPainter {
  _FramePainter(this.color, this.inset);

  final Color color;
  final double inset;

  @override
  void paint(Canvas canvas, Size size) {
    final dx = size.width * inset, dy = size.height * inset;
    final rect = Rect.fromLTRB(dx, dy, size.width - dx, size.height - dy);
    final arm = rect.shortestSide * 0.12;
    const r = 18.0;
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    for (final (o, sx, sy) in [
      (rect.topLeft, 1.0, 1.0),
      (rect.topRight, -1.0, 1.0),
      (rect.bottomLeft, 1.0, -1.0),
      (rect.bottomRight, -1.0, -1.0),
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(o.dx, o.dy + sy * arm)
          ..lineTo(o.dx, o.dy + sy * r)
          ..quadraticBezierTo(o.dx, o.dy, o.dx + sx * r, o.dy)
          ..lineTo(o.dx + sx * arm, o.dy),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(_FramePainter old) => old.color != color || old.inset != inset;
}

/// How a detection is shown on the review screen.
enum BoxState { confirmed, needsCheck, changed, removed }

Color boxColor(BoxState s) => switch (s) {
      BoxState.confirmed => StatusColors.success,
      BoxState.needsCheck => StatusColors.attention,
      BoxState.changed => StatusColors.info,
      BoxState.removed => Colors.transparent,
    };

/// The scan photo with a rounded box and a small label for each detection.
class DetectionOverlay extends StatelessWidget {
  const DetectionOverlay({super.key, required this.image, required this.aspectRatio, required this.boxes});

  final ImageProvider image;
  final double aspectRatio;
  final List<({Box box, String label, BoxState state})> boxes;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.sheet),
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: LayoutBuilder(builder: (context, c) {
          return Stack(
            fit: StackFit.expand,
            children: [
              Image(image: image, fit: BoxFit.cover, semanticLabel: 'Your photo with the ingredients we found'),
              for (final b in boxes)
                AnimatedOpacity(
                  key: ValueKey(b.label + b.box.xMin.toString()),
                  opacity: b.state == BoxState.removed ? 0 : 1,
                  duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 220),
                  child: Stack(children: [
                    Positioned(
                      left: b.box.xMin * c.maxWidth,
                      top: b.box.yMin * c.maxHeight,
                      width: (b.box.xMax - b.box.xMin) * c.maxWidth,
                      height: (b.box.yMax - b.box.yMin) * c.maxHeight,
                      child: _BoxView(color: boxColor(b.state)),
                    ),
                    // The label may be wider than a small box; it is limited by the photo, not the box.
                    Positioned(
                      left: b.box.xMin * c.maxWidth + 4,
                      top: b.box.yMin * c.maxHeight + 4,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: (c.maxWidth * (1 - b.box.xMin) - 8).clamp(40, 200)),
                        child: _Label(text: b.label),
                      ),
                    ),
                  ]),
                ),
            ],
          );
        }),
      ),
    );
  }
}

class _BoxView extends StatelessWidget {
  const _BoxView({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.circular(Radii.control),
        ),
      );
}

class _Label extends StatelessWidget {
  const _Label({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: GraphiteMint.background.withValues(alpha: 0.72), borderRadius: BorderRadius.circular(Radii.pill)),
        child: Text(text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: GraphiteMint.text)),
      );
}
