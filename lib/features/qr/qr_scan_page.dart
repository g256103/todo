import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'qr_payloads.dart';

typedef QrScanResultHandler = void Function(String token);

/// Camera scan for claim QR URLs; falls back to manual entry on unsupported platforms.
class QrScanPage extends StatefulWidget {
  const QrScanPage({super.key, required this.onTokenScanned});

  final QrScanResultHandler onTokenScanned;

  @override
  State<QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends State<QrScanPage> {
  final _manualController = TextEditingController();
  bool _handled = false;

  void _tryHandle(String raw) {
    if (_handled) return;
    final token = extractClaimTokenFromQrContent(raw);
    if (token == null) return;
    _handled = true;
    widget.onTokenScanned(token);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _manualController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final useCamera =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);

    return Scaffold(
      appBar: AppBar(title: const Text('QRを読み取る')),
      body: Column(
        children: [
          if (useCamera)
            Expanded(
              flex: 3,
              child: MobileScanner(
                onDetect: (capture) {
                  for (final barcode in capture.barcodes) {
                    final raw = barcode.rawValue;
                    if (raw != null) _tryHandle(raw);
                  }
                },
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'この端末ではカメラプレビューを表示できません。'
                '読み取ったURLまたはtokenを入力してください。',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
            ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('手動入力（claim URL または token）'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _manualController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'https://paypay-commit.mock/claim?token=...',
                    ),
                    minLines: 2,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () {
                      final raw = _manualController.text.trim();
                      if (raw.isEmpty) return;
                      final token = extractClaimTokenFromQrContent(raw) ?? raw;
                      _handled = true;
                      widget.onTokenScanned(token);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    child: const Text('この内容で利用'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
