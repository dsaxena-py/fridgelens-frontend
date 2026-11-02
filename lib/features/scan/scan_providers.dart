import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/models.dart';

/// Cameras on this device. Tests override it (an empty list means "no camera").
final camerasProvider = FutureProvider<List<CameraDescription>>((ref) => availableCameras());

/// Picks a photo from the gallery, already shrunk and re-encoded as JPEG (this also converts
/// iPhone HEIC photos). Tests override it.
final pickPhotoProvider = Provider<Future<File?> Function()>((ref) => () async {
      final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, maxHeight: 1600, imageQuality: 88);
      return x == null ? null : File(x.path);
    });

/// What the review screen needs: the server's scan and the photo the user took.
class ScanReviewArgs {
  const ScanReviewArgs({required this.scan, required this.photo});

  final Scan scan;
  final File photo;
}
