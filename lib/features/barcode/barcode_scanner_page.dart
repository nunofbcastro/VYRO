import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../app/app_services.dart';
import '../../app/l10n/strings.dart';
import '../../app/theme/vyro_chrome.dart';
import '../../app/theme/vyro_shell.dart';
import '../../app/theme/vyro_theme.dart';
import '../nutrition/data/open_food_facts_repository.dart';
import '../nutrition/domain/food_product.dart';
import 'product_detail_page.dart';

class BarcodeScannerPage extends StatefulWidget {
  const BarcodeScannerPage({super.key, required this.day});
  final DateTime day;

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> {
  final TextEditingController _codeController = TextEditingController();
  bool _cameraEnabled = false;
  bool _lookingUp = false;
  String? _message;

  /// Last code read by the camera. The camera keeps streaming after we
  /// return from the product page, so the same code is ignored once.
  String? _lastScanned;
  Future<List<FoodProduct>>? _recent;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _recent ??= AppServicesScope.of(
      context,
    ).productLookupRepository.recentProducts();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final theme = Theme.of(context);
    return VyroSubpageScaffold(
      title: t.get('barcode'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          _Viewfinder(
            cameraEnabled: _cameraEnabled,
            lookingUp: _lookingUp,
            onStart: kIsWeb
                ? null
                : () => setState(() => _cameraEnabled = true),
            onDetect: _onDetect,
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 14,
                color: theme.textTheme.bodySmall?.color,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  t.get(kIsWeb ? 'scannerWebNote' : 'scannerPrivacy'),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          VyroSectionTitle(label: t.get('typeBarcode')),
          TextField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.search,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 13,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
            decoration: InputDecoration(
              hintText: t.get('barcodeHint'),
              counterText: '',
              prefixIcon: const Icon(Icons.dialpad_rounded),
              suffixIcon: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: IconButton.filled(
                  tooltip: t.get('lookup'),
                  onPressed: _lookingUp
                      ? null
                      : () => _lookup(_codeController.text),
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
              ),
            ),
            onSubmitted: _lookup,
          ),
          if (_lookingUp || _message != null) ...[
            const SizedBox(height: 10),
            _StatusLine(lookingUp: _lookingUp, message: _message),
          ],
          const SizedBox(height: 24),
          VyroSectionTitle(label: t.get('recentProducts')),
          FutureBuilder<List<FoodProduct>>(
            future: _recent,
            builder: (context, snapshot) {
              final products = snapshot.data ?? const <FoodProduct>[];
              if (products.isEmpty) {
                return Text(
                  t.get('recentProductsEmpty'),
                  style: theme.textTheme.bodySmall,
                );
              }
              return VyroCard(
                padding: EdgeInsets.zero,
                radius: 20,
                child: Column(
                  children: [
                    for (var i = 0; i < products.length; i++) ...[
                      if (i > 0) const Divider(indent: 16, endIndent: 16),
                      _RecentTile(
                        product: products[i],
                        onTap: () => _open(products[i]),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _onDetect(BarcodeCapture capture) {
    if (_lookingUp) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && value.isNotEmpty && value != _lastScanned) {
        _lastScanned = value;
        HapticFeedback.selectionClick();
        _codeController.text = value;
        _lookup(value);
        return;
      }
    }
  }

  Future<void> _open(FoodProduct product) async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailPage(product: product, day: widget.day),
      ),
    );
    if (!mounted) return;
    if (added == true) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _recent = AppServicesScope.of(
          context,
        ).productLookupRepository.recentProducts();
      });
    }
  }

  Future<void> _lookup(String code) async {
    if (_lookingUp) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _lookingUp = true;
      _message = null;
    });
    final services = AppServicesScope.of(context);
    final t = stringsOf(context);
    try {
      final product = await services.productLookupRepository.findByBarcode(
        code,
        languageCode: t.isEnglish ? 'en' : 'pt',
      );
      if (!mounted) return;
      if (product == null) {
        setState(() => _message = t.get('productNotFound'));
      } else {
        setState(() => _lookingUp = false);
        await _open(product);
      }
    } on ProductLookupException catch (error) {
      if (!mounted) return;
      final key = switch (error.message) {
        'invalid barcode' => 'invalidBarcode',
        'offline' => 'lookupOffline',
        'rate limited' => 'rateLimit',
        _ => 'lookupError',
      };
      setState(() => _message = t.get(key));
    } catch (_) {
      if (mounted) setState(() => _message = t.get('lookupError'));
    } finally {
      if (mounted) setState(() => _lookingUp = false);
    }
  }
}

/// Camera area. The camera only starts after an explicit tap; until then a
/// static frame explains what will happen.
class _Viewfinder extends StatelessWidget {
  const _Viewfinder({
    required this.cameraEnabled,
    required this.lookingUp,
    required this.onStart,
    required this.onDetect,
  });
  final bool cameraEnabled;
  final bool lookingUp;
  final VoidCallback? onStart;
  final void Function(BarcodeCapture) onDetect;

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final dark = theme.brightness == Brightness.dark;
    return AspectRatio(
      aspectRatio: 1.15,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (cameraEnabled)
              MobileScanner(
                onDetect: onDetect,
                errorBuilder: (context, error) => _CenteredNote(
                  icon: Icons.videocam_off_outlined,
                  text: t.get('cameraError'),
                ),
              )
            else
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: dark
                        ? const [Color(0xFF14181D), Color(0xFF0D1013)]
                        : const [Color(0xFFFFFFFF), Color(0xFFF0F5E8)],
                  ),
                  border: Border.all(color: theme.colorScheme.outline),
                  borderRadius: BorderRadius.circular(26),
                ),
              ),
            IgnorePointer(
              child: Center(
                child: FractionallySizedBox(
                  widthFactor: 0.72,
                  heightFactor: 0.42,
                  child: CustomPaint(
                    painter: _CornersPainter(
                      color: cameraEnabled ? Colors.white : accent,
                    ),
                  ),
                ),
              ),
            ),
            if (!cameraEnabled)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(
                      Icons.barcode_reader,
                      size: 30,
                      color: VyroTheme.accentTextOf(context),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      t.get('pointCamera'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 14),
                    if (onStart != null)
                      FilledButton.icon(
                        onPressed: onStart,
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: Text(t.get('startScanner')),
                      ),
                  ],
                ),
              ),
            if (cameraEnabled)
              Positioned(
                left: 0,
                right: 0,
                bottom: 18,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      t.get('pointCamera'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            if (lookingUp && cameraEnabled)
              const ColoredBox(
                color: Colors.black54,
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}

class _CornersPainter extends CustomPainter {
  _CornersPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    const r = 18.0;
    final len = size.shortestSide * 0.28;
    final w = size.width;
    final h = size.height;
    Path corner(Offset o, double dx, double dy) => Path()
      ..moveTo(o.dx, o.dy + dy * len)
      ..lineTo(o.dx, o.dy + dy * r)
      ..quadraticBezierTo(o.dx, o.dy, o.dx + dx * r, o.dy)
      ..lineTo(o.dx + dx * len, o.dy);
    canvas
      ..drawPath(corner(Offset.zero, 1, 1), paint)
      ..drawPath(corner(Offset(w, 0), -1, 1), paint)
      ..drawPath(corner(Offset(0, h), 1, -1), paint)
      ..drawPath(corner(Offset(w, h), -1, -1), paint);
    final line = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(w * 0.12, h / 2), Offset(w * 0.88, h / 2), line);
  }

  @override
  bool shouldRepaint(_CornersPainter oldDelegate) => oldDelegate.color != color;
}

class _CenteredNote extends StatelessWidget {
  const _CenteredNote({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    ),
  );
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.lookingUp, required this.message});
  final bool lookingUp;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (lookingUp) {
      return Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Text(
            stringsOf(context).get('lookingUp'),
            style: theme.textTheme.bodyMedium,
          ),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.error_outline_rounded,
          size: 18,
          color: theme.colorScheme.error,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ),
      ],
    );
  }
}

class _RecentTile extends StatelessWidget {
  const _RecentTile({required this.product, required this.onTap});
  final FoodProduct product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meta = [
      if (product.brand != null) product.brand!,
      if (product.kcalPer100g != null)
        '${product.kcalPer100g!.round()} kcal / 100 ${product.liquid ? 'ml' : 'g'}',
    ].join(' · ');
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                product.liquid
                    ? Icons.local_drink_outlined
                    : Icons.inventory_2_outlined,
                size: 19,
                color: VyroTheme.accentTextOf(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (meta.isNotEmpty)
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            Icon(
              Icons.add_circle_outline_rounded,
              color: VyroTheme.accentTextOf(context),
            ),
          ],
        ),
      ),
    );
  }
}
