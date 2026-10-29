// Renders the launch-screen and app-icon images from the same painter the app uses.
// Run: flutter test tool/render_brand_assets_test.dart
// then: dart run flutter_native_splash:create && dart run flutter_launcher_icons
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meallens/theme/tokens.dart';
import 'package:meallens/widgets/logo.dart';

Future<void> _render(String path, {required double canvas, required double mark, Color? background,
    required Color ink, required Color detail}) async {
  final recorder = ui.PictureRecorder();
  final c = Canvas(recorder);
  if (background != null) c.drawRect(Rect.fromLTWH(0, 0, canvas, canvas), Paint()..color = background);
  c.translate((canvas - mark) / 2, (canvas - mark) / 2);
  PlateFocusPainter(ink: ink, detail: detail, showDetail: true).paint(c, Size.square(mark));
  final image = await recorder.endRecording().toImage(canvas.round(), canvas.round());
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(png!.buffer.asUint8List());
}

void main() {
  test('render brand assets', () async {
    // Launch screen: transparent, mark well inside Android 12's circular mask (2/3 of the canvas).
    await _render('assets/brand/splash_mark.png', canvas: 1152, mark: 560,
        ink: MistEucalyptus.text, detail: MistEucalyptus.accentStrong);
    await _render('assets/brand/splash_mark_dark.png', canvas: 1152, mark: 560,
        ink: GraphiteMint.text, detail: GraphiteMint.accent);
    // App icon: opaque Mist background (iOS icons cannot be transparent).
    await _render('assets/brand/app_icon.png', canvas: 1024, mark: 560, background: MistEucalyptus.background,
        ink: MistEucalyptus.text, detail: MistEucalyptus.accentStrong);
    // Android adaptive icon foreground: transparent, mark inside the 66% safe zone.
    await _render('assets/brand/app_icon_foreground.png', canvas: 1024, mark: 480,
        ink: MistEucalyptus.text, detail: MistEucalyptus.accentStrong);
  });
}
