import 'dart:typed_data';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../../../app/l10n/strings.dart';

Future<Uint8List?> selectPhotoRegion(BuildContext context, Uint8List bytes) =>
    showModalBottomSheet<Uint8List>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _RegionSheet(bytes),
    );

Uint8List cropPhotoRegion((Uint8List, List<double>) input) {
  final decoded = img.decodeImage(input.$1);
  if (decoded == null) throw const FormatException('Invalid image');
  final image = img.bakeOrientation(decoded);
  final r = input.$2;
  final x = (r[0] * image.width).floor().clamp(0, image.width - 1);
  final y = (r[1] * image.height).floor().clamp(0, image.height - 1);
  final width = ((r[2] - r[0]) * image.width).ceil().clamp(1, image.width - x);
  final height = ((r[3] - r[1]) * image.height).ceil().clamp(
    1,
    image.height - y,
  );
  return Uint8List.fromList(
    img.encodeJpg(
      img.copyCrop(image, x: x, y: y, width: width, height: height),
      quality: 90,
    ),
  );
}

double _aspect(Uint8List bytes) {
  final image = img.decodeImage(bytes);
  if (image == null) throw const FormatException('Invalid image');
  final upright = img.bakeOrientation(image);
  return upright.width / upright.height;
}

class _RegionSheet extends StatefulWidget {
  const _RegionSheet(this.bytes);
  final Uint8List bytes;
  @override
  State<_RegionSheet> createState() => _RegionSheetState();
}

class _RegionSheetState extends State<_RegionSheet> {
  late final _ratio = compute(_aspect, widget.bytes);
  Rect _selection = const Rect.fromLTRB(.1, .1, .9, .9);
  Offset? _start;
  bool _busy = false;
  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .86,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              t.get('photoRegionTitle'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(t.get('photoRegionHint')),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<double>(
                future: _ratio,
                builder: (context, snapshot) {
                  if (snapshot.hasError)
                    return Text(t.get('photoInvalidImage'));
                  if (!snapshot.hasData)
                    return const Center(child: CircularProgressIndicator());
                  return LayoutBuilder(
                    builder: (context, box) {
                      final ar = snapshot.data!;
                      final width = box.maxWidth
                          .clamp(0, box.maxHeight * ar)
                          .toDouble();
                      final height = width / ar;
                      Offset point(Offset p) => Offset(
                        (p.dx / width).clamp(0, 1),
                        (p.dy / height).clamp(0, 1),
                      );
                      return Center(
                        child: SizedBox(
                          width: width,
                          height: height,
                          child: GestureDetector(
                            onPanStart: _busy
                                ? null
                                : (d) => _start = point(d.localPosition),
                            onPanUpdate: _busy
                                ? null
                                : (d) {
                                    final start = _start;
                                    if (start != null)
                                      setState(
                                        () => _selection = Rect.fromPoints(
                                          start,
                                          point(d.localPosition),
                                        ),
                                      );
                                  },
                            onTapUp: _busy
                                ? null
                                : (d) {
                                    final p = point(d.localPosition);
                                    setState(
                                      () => _selection = Rect.fromLTWH(
                                        (p.dx - .2).clamp(0, .6),
                                        (p.dy - .2).clamp(0, .6),
                                        .4,
                                        .4,
                                      ),
                                    );
                                  },
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.memory(widget.bytes, fit: BoxFit.fill),
                                Positioned.fromRect(
                                  rect: Rect.fromLTRB(
                                    _selection.left * width,
                                    _selection.top * height,
                                    _selection.right * width,
                                    _selection.bottom * height,
                                  ),
                                  child: IgnorePointer(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withValues(alpha: .12),
                                        border: Border.all(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                          width: 3,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed:
                  _busy || _selection.width < .03 || _selection.height < .03
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      try {
                        final result = await compute(cropPhotoRegion, (
                          widget.bytes,
                          [
                            _selection.left,
                            _selection.top,
                            _selection.right,
                            _selection.bottom,
                          ],
                        ));
                        if (context.mounted) Navigator.pop(context, result);
                      } catch (_) {
                        if (mounted) setState(() => _busy = false);
                      }
                    },
              icon: Icon(_busy ? Icons.hourglass_top : Icons.crop),
              label: Text(t.get('photoRegionAnalyse')),
            ),
          ],
        ),
      ),
    );
  }
}
