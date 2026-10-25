import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';

import '../data/food_database.dart';
import '../food_vision/food_vision.dart';

/// One editable line of the photo review list.
class ReviewItem {
  ReviewItem(DetectedFood detected)
    : original = detected,
      detected = detected,
      grams = detected.grams;

  /// The result line this item was last reconciled with (learning uses it).
  DetectedFood original;
  DetectedFood detected;
  double grams;

  /// Set while the line collapses out of the list (animated removal).
  bool removing = false;

  /// Scroll target for "choose the first unresolved food".
  final anchor = GlobalKey();

  FoodRef? get food => detected.food;
  double? get kcal => food == null ? null : food!.kcal * grams / 100;

  /// A draft line the verification pass has not confirmed yet.
  bool get pending => detected.pending;

  /// Counts for the meal total: matched, not pending, with an amount.
  bool get savable => !removing && !pending && food != null && grams > 0;

  /// Needs the user to name the food (no database match yet).
  bool get unresolved => !removing && !pending && food == null;

  /// Identity used to match a draft line with the final line.
  String get matchKey => detected.food?.key ?? detected.label.toLowerCase();
}

/// Counts shown on the review CTA.
class ReviewCounts {
  const ReviewCounts({
    required this.savable,
    required this.unresolved,
    required this.pending,
  });

  final int savable;
  final int unresolved;
  final int pending;

  bool get hasUnresolved => unresolved > 0;
}

ReviewCounts countReview(Iterable<ReviewItem> items) {
  var savable = 0, unresolved = 0, pending = 0;
  for (final item in items) {
    if (item.removing) continue;
    if (item.pending) pending++;
    if (item.savable) savable++;
    if (item.unresolved) unresolved++;
  }
  return ReviewCounts(
    savable: savable,
    unresolved: unresolved,
    pending: pending,
  );
}

/// Reconciles [current] with an incoming draft or final list.
///
/// A line that is still present keeps its identity (so its card is not
/// rebuilt from scratch and any state stays attached to it). Lines that are
/// no longer in [incoming] are flagged [ReviewItem.removing] and kept at the
/// end until the UI has animated them out. New lines are appended in order.
List<ReviewItem> mergeReviewItems(
  List<ReviewItem>? current,
  List<DetectedFood> incoming,
) {
  final old = [...?current];
  final used = <ReviewItem>{};
  final next = <ReviewItem>[];
  for (final detected in incoming) {
    final key = detected.food?.key ?? detected.label.toLowerCase();
    ReviewItem? match;
    for (final item in old) {
      if (!item.removing && !used.contains(item) && item.matchKey == key) {
        match = item;
        break;
      }
    }
    if (match == null) {
      next.add(ReviewItem(detected));
      continue;
    }
    used.add(match);
    match
      ..original = detected
      ..detected = detected
      ..grams = detected.grams;
    next.add(match);
  }
  for (final item in old) {
    if (!used.contains(item) && !item.removing) {
      item.removing = true;
    }
    if (item.removing && !next.contains(item)) next.add(item);
  }
  return next;
}

enum ShotState {
  /// Picked but not analysed yet (the photo may still be a file).
  waiting,

  /// Analysis running; draft lines may already be shown.
  analysing,

  /// Final result available (possibly empty, with a failure).
  ready,

  /// Saved to the diary or passed over. Photo bytes released.
  done,
}

/// One photo, or two photos of the same meal, awaiting review.
class ReviewShot {
  ReviewShot({this.file, this.secondFile, this.bytes, this.limitNote = false});

  /// Picker files, read (and deleted) only when the analysis starts.
  XFile? file;
  XFile? secondFile;

  /// The photo in memory. Kept only while this shot is current or prefetched.
  Uint8List? bytes;
  Uint8List? second;

  /// A second angle added from the camera after the first analysis (shown as
  /// a thumbnail only; its candidates are offered in a sheet).
  Uint8List? angle;

  /// True when a same-meal selection had more than two photos.
  final bool limitNote;

  ShotState state = ShotState.waiting;

  /// Bumped on every new analysis and on release: late events are ignored.
  int generation = 0;
  List<ReviewItem>? items;
  FoodVisionResult? result;
  VisionFailure? failure;

  /// Translation key of a reading error, shown as a notice.
  String? error;
  final reviewClock = Stopwatch();

  bool get hasPhoto => bytes != null || file != null;
  bool get draftShown => result?.stage == VisionStage.draft;

  /// Drops the photo bytes and invalidates running analyses.
  void release() {
    bytes = null;
    second = null;
    angle = null;
    generation++;
  }
}
