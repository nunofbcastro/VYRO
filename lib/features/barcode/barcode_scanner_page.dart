import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../app/app_services.dart';
import '../../app/l10n/strings.dart';
import '../../core/widgets/vyro_widgets.dart';
import '../nutrition/data/open_food_facts_repository.dart';
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

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.get('barcode'))),
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Align(alignment: Alignment.centerLeft, child: DemoBadge()),
            ),
            if (!_cameraEnabled)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.qr_code_scanner,
                        size: 64,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 18),
                      Text(t.get('scannerIntro'), textAlign: TextAlign.center),
                      const SizedBox(height: 18),
                      if (kIsWeb)
                        Text(
                          t.get('manualOnlyWeb'),
                          textAlign: TextAlign.center,
                        )
                      else
                        FilledButton.icon(
                          onPressed: () =>
                              setState(() => _cameraEnabled = true),
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: Text(t.get('startScanner')),
                        ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      fit: StackFit.expand,
                      alignment: Alignment.center,
                      children: [
                        MobileScanner(
                          onDetect: _onDetect,
                          errorBuilder: (context, error) => Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Text(
                                t.get('cameraError'),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                        IgnorePointer(
                          child: Center(
                            child: Container(
                              width: 280,
                              height: 150,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                          ),
                        ),
                        if (_lookingUp)
                          ColoredBox(
                            color: Colors.black54,
                            child: Center(
                              child: CircularProgressIndicator(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                children: [
                  TextField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      labelText: t.get('manualBarcode'),
                      hintText: t.get('barcodeHint'),
                      suffixIcon: IconButton(
                        tooltip: t.get('lookup'),
                        onPressed: _lookingUp
                            ? null
                            : () => _lookup(_codeController.text),
                        icon: const Icon(Icons.search),
                      ),
                    ),
                    onSubmitted: _lookup,
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _message!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onDetect(BarcodeCapture capture) {
    if (_lookingUp) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && value.isNotEmpty) {
        _codeController.text = value;
        _lookup(value);
        return;
      }
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
        final added = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ProductDetailPage(product: product, day: widget.day),
          ),
        );
        if (added == true && mounted) Navigator.pop(context, true);
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
