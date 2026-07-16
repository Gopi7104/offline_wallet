import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:offline_wallet/components/components.dart';
import 'package:offline_wallet/theme/theme.dart';
import 'scan_qr_screen.dart';

/// Pay screen — entry to the Customer Pay flow (ARCHITECTURE.md §6.1 `pay/`).
class PayScreen extends StatelessWidget {
  const PayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pay')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: AppColors.balanceGradient),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Symbols.qr_code_scanner_rounded, size: 44, color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Scan a merchant QR to pay',
                style: AppTypography.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.s),
              Text(
                "Point your camera at the merchant's payment QR code.",
                style: AppTypography.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xxl),
              PrimaryButton(
                key: const Key('scan-qr-button'),
                label: 'Scan QR',
                icon: Symbols.qr_code_scanner_rounded,
                onPressed: () => Navigator.of(context).push(
                  sharedAxisRoute(const ScanQrScreen()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
