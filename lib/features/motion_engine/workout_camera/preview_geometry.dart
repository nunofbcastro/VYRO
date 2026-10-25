import 'dart:ui' show Size;

import 'package:flutter/services.dart' show DeviceOrientation;

/// Whether the camera preview is shown in landscape. `CameraPreview` makes the
/// same decision from the orientation it is given.
bool isLandscapePreview(DeviceOrientation orientation) =>
    orientation == DeviceOrientation.landscapeLeft ||
    orientation == DeviceOrientation.landscapeRight;

/// Size of the upright preview box, in the same units as the camera's
/// `previewSize`.
///
/// `CameraPreview` lays its image out with the sensor aspect ratio in
/// landscape and the inverse ratio in portrait. The box that holds the image
/// and the skeleton overlay must use the same ratio, otherwise the image is
/// stretched. So: landscape keeps `previewSize` as it is, portrait swaps width
/// and height.
Size uprightPreviewSize(Size previewSize, {required bool landscape}) =>
    landscape ? previewSize : Size(previewSize.height, previewSize.width);
