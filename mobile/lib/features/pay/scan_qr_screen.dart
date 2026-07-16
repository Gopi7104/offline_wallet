import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:offline_wallet/domain/qr_codec.dart';
import 'package:offline_wallet/theme/theme.dart';
import 'merchant_summary_screen.dart';

/// Scan QR screen (ARCHITECTURE.md §6.1 `pay/` — payer role, `mobile_scanner`).
/// Camera-based scanning of the merchant payment QR. On a valid scan it
/// auto-navigates to the Merchant Summary; malformed/unsupported codes show a
/// friendly error and scanning continues. No BLE, transfer, or settlement.
class ScanQrScreen extends StatefulWidget {
  /// Test seam: when set, this raw value is processed once (as if scanned) after
  /// the first frame, and the camera is NOT started. Lets navigation/parse/error
  /// logic be tested without a device camera. Never set in production.
  final String? debugInitialScan;

  const ScanQrScreen({super.key, this.debugInitialScan});

  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen> {
  bool _handled = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final injected = widget.debugInitialScan;
    if (injected != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _handleRaw(injected);
      });
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (capture.barcodes.isEmpty) return;
    final raw = capture.barcodes.first.rawValue;
    if (raw != null) _handleRaw(raw);
  }

  void _handleRaw(String raw) {
    if (_handled) return; // ignore further frames once a valid code is accepted
    try {
      final payload = parseMerchantQr(raw);
      _handled = true;
      Navigator.of(context).pushReplacement(
        sharedAxisRoute(MerchantSummaryScreen(payload: payload)),
      );
    } on QrFormatException catch (e) {
      setState(() => _error = e.message); // keep scanning
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR'), backgroundColor: Colors.black),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (widget.debugInitialScan == null)
            MobileScanner(onDetect: _onDetect)
          else
            const ColoredBox(
              color: Colors.black,
              child: Center(
                child: Text(
                  'Scanner (test mode)',
                  key: Key('scanner-test-mode'),
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          IgnorePointer(
            child: CustomPaint(painter: _ScanFramePainter()),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.l,
                AppSpacing.xl,
                AppSpacing.xxl,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.black87],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.s),
                      child: Text(
                        _error!,
                        key: const Key('scan-error'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.w600),
                      ),
                    ),
                  const Text(
                    "Point the camera at the merchant's payment QR",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white),
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

/// Subtle rounded viewfinder frame overlay — purely decorative.
class _ScanFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final frameSize = size.width * 0.7;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2.4),
      width: frameSize,
      height: frameSize,
    );
    final paint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(AppRadius.lg)), paint);
  }

  @override
  bool shouldRepaint(covariant _ScanFramePainter oldDelegate) => false;
}
