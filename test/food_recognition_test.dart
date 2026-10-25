import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/features/nutrition/domain/food_recognition_service.dart';

/// Regression: the bundled AIY Food V1 model is uint8 (192×192 input,
/// quantized softmax output). The service used to require float32 224×224
/// tensors and failed on every photo with "unsupported_model_tensor".
void main() {
  test('dequantize applies scale and zero point', () {
    expect(dequantize([0, 128, 255], scale: 1 / 256, zeroPoint: 0), [
      0,
      0.5,
      255 / 256,
    ]);
    expect(dequantize([138], scale: 0.0078125, zeroPoint: 128), [0.078125]);
  });

  test('ranking skips background and keeps confident foods', () {
    final labels = {0: '__background__', 1: 'Rice', 2: 'Beans', 3: 'Salad'};
    final ranked = rankCandidates([0.6, 0.2, 0.15, 0.005], labels);
    expect(ranked.map((c) => c.label), ['Rice', 'Beans']);
    expect(ranked.first.confidence, closeTo(0.2, 1e-9));
  });

  test('nothing is returned when no food is likely', () {
    final labels = {0: '__background__', 1: 'Rice'};
    expect(rankCandidates([0.98, 0.02], labels), isEmpty);
  });
}
