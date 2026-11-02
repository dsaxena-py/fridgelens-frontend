import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/scan.dart';
import 'scan_providers.dart';

/// Camera with four calm corner markers (§7). The camera UI stays dark in both themes so the
/// preview reads clearly, using the Graphite Mint palette.
class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

enum _CameraState { starting, ready, denied, unavailable }

class _CameraScreenState extends ConsumerState<CameraScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  _CameraState _state = _CameraState.starting;
  File? _processing; // the photo being uploaded
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Release the camera in the background and take it again on return, as the plugin requires.
    final c = _controller;
    if (state == AppLifecycleState.inactive && c != null && c.value.isInitialized) {
      _controller = null;
      c.dispose();
      if (mounted) setState(() => _state = _CameraState.starting);
    } else if (state == AppLifecycleState.resumed && _controller == null && _state == _CameraState.starting) {
      _startCamera();
    }
  }

  Future<void> _startCamera() async {
    try {
      final cameras = await ref.read(camerasProvider.future);
      if (cameras.isEmpty) {
        if (mounted) setState(() => _state = _CameraState.unavailable);
        return;
      }
      final back = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cameras.first);
      final controller = CameraController(back, ResolutionPreset.veryHigh, enableAudio: false, imageFormatGroup: ImageFormatGroup.jpeg);
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _state = _CameraState.ready;
      });
    } on CameraException catch (e) {
      final denied = e.code.contains('AccessDenied') || e.code.contains('AccessRestricted');
      if (mounted) setState(() => _state = denied ? _CameraState.denied : _CameraState.unavailable);
    }
  }

  Future<void> _capture() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || c.value.isTakingPicture || _processing != null) return;
    try {
      final shot = await c.takePicture();
      await _process(File(shot.path));
    } on CameraException {
      if (mounted) setState(() => _error = "We couldn't take that photo. Try again.");
    }
  }

  Future<void> _pickFromGallery() async {
    final file = await ref.read(pickPhotoProvider)();
    if (file != null) await _process(file);
  }

  Future<void> _process(File photo) async {
    setState(() {
      _processing = photo;
      _error = null;
    });
    try {
      final scan = await ref.read(apiProvider).uploadScan(photo);
      if (mounted) context.pushReplacement('/scan/review', extra: ScanReviewArgs(scan: scan, photo: photo));
    } catch (e) {
      if (mounted) {
        setState(() {
          _processing = null;
          _error = errorText(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Theme(
      data: Theme.of(context).copyWith(brightness: Brightness.dark),
      child: Scaffold(
        backgroundColor: GraphiteMint.background,
        body: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.sm, Space.sm, Space.lg, 0),
              child: Row(children: [
                IconButton(
                  tooltip: 'Close',
                  color: GraphiteMint.text,
                  icon: const Icon(Icons.close_rounded),
                  onPressed: _processing == null ? () => context.pop() : null,
                ),
                const SizedBox(width: Space.xs),
                Text('Scan ingredients', style: text.titleLarge?.copyWith(color: GraphiteMint.text)),
              ]),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.screen, vertical: Space.lg),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.sheet),
                  child: ColoredBox(color: GraphiteMint.surface, child: _viewfinder()),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.xl),
              child: _error != null
                  ? InlineBanner(text: _error!, isError: true)
                  : Text(
                      _processing != null ? 'Finding ingredients…' : 'Keep ingredients visible and use even lighting.',
                      style: text.bodyLarge?.copyWith(color: GraphiteMint.textMuted),
                      textAlign: TextAlign.center,
                    ),
            ),
            const SizedBox(height: Space.lg),
            _controls(),
            const SizedBox(height: Space.xl),
          ]),
        ),
      ),
    );
  }

  Widget _viewfinder() {
    final processing = _processing;
    if (processing != null) {
      return Stack(fit: StackFit.expand, children: [
        Image.file(processing, fit: BoxFit.cover, color: Colors.black26, colorBlendMode: BlendMode.darken),
        const Align(alignment: Alignment.bottomCenter, child: LinearProgressIndicator(minHeight: 3, color: GraphiteMint.accent)),
      ]);
    }
    final c = _controller;
    return switch (_state) {
      _CameraState.ready when c != null => Stack(fit: StackFit.expand, children: [
          FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: c.value.previewSize?.height ?? 3,
              height: c.value.previewSize?.width ?? 4,
              child: CameraPreview(c),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(Space.xl),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.06, end: 0),
              duration: motion(context, const Duration(milliseconds: 450)),
              curve: Curves.easeOutCubic,
              builder: (context, inset, _) => ScanFrame(inset: inset),
            ),
          ),
        ]),
      _CameraState.denied => _Notice(
          icon: Icons.no_photography_outlined,
          text: 'MealLens needs the camera to scan. You can allow it in your phone settings, or choose a photo instead.',
        ),
      _CameraState.unavailable => _Notice(
          icon: Icons.photo_library_outlined,
          text: 'No camera is available here. Choose a photo of your fridge instead.',
        ),
      _ => const Center(child: CircularProgressIndicator(color: GraphiteMint.accent)),
    };
  }

  Widget _controls() {
    final busy = _processing != null;
    final canShoot = _state == _CameraState.ready && !busy;
    return Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
      _RoundAction(icon: Icons.photo_library_outlined, label: 'Gallery', onTap: busy ? null : _pickFromGallery),
      Semantics(
        button: true,
        label: 'Take photo',
        enabled: canShoot,
        child: GestureDetector(
          onTap: canShoot ? _capture : null,
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: GraphiteMint.accent, width: 3)),
            padding: const EdgeInsets.all(5),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: canShoot ? GraphiteMint.text : GraphiteMint.surfaceElevated,
              ),
            ),
          ),
        ),
      ),
      const SizedBox(width: 64), // balances the gallery button so the shutter stays centred
    ]);
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 64,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          IconButton.filledTonal(
            onPressed: onTap,
            tooltip: label,
            style: IconButton.styleFrom(backgroundColor: GraphiteMint.surfaceElevated, foregroundColor: GraphiteMint.text),
            icon: Icon(icon),
          ),
          Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: GraphiteMint.textMuted)),
        ]),
      );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Center(
        // Scrolls when the viewfinder is short (small phones, large text).
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Space.xl),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 40, color: GraphiteMint.textMuted),
            const SizedBox(height: Space.lg),
            Text(text,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: GraphiteMint.text)),
          ]),
        ),
      );
}
