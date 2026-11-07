import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Cheap on-device checks so we can ask for a better photo instead of guessing.
class PhotoQuality {
  const PhotoQuality({
    this.tooSmall = false,
    this.tooDark = false,
    this.tooBright = false,
    this.tooBlurry = false,
  });

  final bool tooSmall;
  final bool tooDark;
  final bool tooBright;
  final bool tooBlurry;

  bool get ok => !tooSmall && !tooDark && !tooBright && !tooBlurry;

  /// String key for [FoodVisionResult.note] / UI copy.
  String? get note => tooSmall
      ? 'photoTooSmall'
      : tooDark
      ? 'photoTooDark'
      : tooBright
      ? 'photoTooBright'
      : tooBlurry
      ? 'photoTooBlurry'
      : null;
}

PhotoQuality assessPhotoBytes(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return const PhotoQuality(tooSmall: true);
  return assessPhoto(decoded);
}

PhotoQuality assessPhoto(img.Image image) {
  final shortest = image.width < image.height ? image.width : image.height;
  if (shortest < 96) return const PhotoQuality(tooSmall: true);

  final sample = img.copyResize(image, width: 128);
  const step = 1;
  var n = 0;
  var sum = 0.0;
  var detailSum = 0.0;
  var detailSq = 0.0;
  double luminance(int x, int y) {
    final p = sample.getPixel(x, y);
    return 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
  }

  for (var y = 1; y < sample.height - 1; y += step) {
    for (var x = 1; x < sample.width - 1; x += step) {
      final px = sample.getPixel(x, y);
      final lum = 0.299 * px.r + 0.587 * px.g + 0.114 * px.b;
      sum += lum;
      final lap =
          4 * lum -
          luminance(x - 1, y) -
          luminance(x + 1, y) -
          luminance(x, y - 1) -
          luminance(x, y + 1);
      detailSum += lap;
      detailSq += lap * lap;
      n++;
    }
  }
  if (n == 0) return const PhotoQuality(tooSmall: true);
  final mean = sum / n;
  final variance = detailSq / n - (detailSum / n) * (detailSum / n);
  return PhotoQuality(
    tooDark: mean < 26,
    tooBright: mean > 248,
    // Heuristic warning, never a hard rejection or a calibrated probability.
    tooBlurry: variance < 12,
  );
}

/// Mean luminance of a small sample (0–255). Used to decide whether a meal
/// photo is dark enough to lift before recognition.
double meanLuminance(img.Image image) {
  final sample = image.width <= 48 ? image : img.copyResize(image, width: 48);
  var sum = 0.0;
  var n = 0;
  for (final p in sample) {
    sum += 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
    n++;
  }
  return n == 0 ? 0 : sum / n;
}

/// Makes the plate larger in the frame and lifts a dark photo.
///
/// Phone photos are mostly table around a small plate. Both the on-device
/// model and the dish classifier then see background. Trimming the outer
/// 12% keeps food near the edge (a glass beside the plate) and drops the
/// empty border. A bright photo is not recolored. Never rejects the photo.
img.Image focusMealPhoto(img.Image source) {
  // Tiny images are probes and icons. Trimming them below 16 px throws,
  // and there is no plate border to remove.
  if (source.width < 32 || source.height < 32) return source;
  final mean = meanLuminance(source);
  // gamma < 1 lifts shadows (image package: pow(channel/255, gamma)*255).
  // Bright and near-black photos are left alone.
  final lifted = (mean >= 78 || mean < 12)
      ? source
      : img.gamma(source, gamma: 0.75);
  const keep = 0.88;
  final width = (lifted.width * keep).round();
  final height = (lifted.height * keep).round();
  if (width >= lifted.width && height >= lifted.height) return lifted;
  return img.copyCrop(
    lifted,
    x: (lifted.width - width) ~/ 2,
    y: (lifted.height - height) ~/ 2,
    width: width,
    height: height,
  );
}
