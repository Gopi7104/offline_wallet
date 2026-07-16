import 'package:flutter/material.dart';
import 'package:offline_wallet/components/components.dart';
import 'package:offline_wallet/theme/theme.dart';
import 'load_processing_screen.dart';

/// UPI PIN entry — UI simulation only (Task 6.6). Any 6-digit PIN succeeds;
/// there is no real UPI network call and no backend PIN validation.
class UpiPinScreen extends StatefulWidget {
  final int amountPaise;
  const UpiPinScreen({super.key, required this.amountPaise});

  @override
  State<UpiPinScreen> createState() => _UpiPinScreenState();
}

class _UpiPinScreenState extends State<UpiPinScreen> {
  static const _pinLength = 6;
  final _pinIndicatorKey = GlobalKey<PinIndicatorState>();
  String _pin = '';
  String? _error;

  void _onDigit(String digit) {
    if (_pin.length >= _pinLength) return;
    setState(() {
      _pin += digit;
      _error = null;
    });
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  void _onVerify() {
    if (_pin.length < _pinLength) {
      setState(() => _error = 'Enter all 6 digits');
      _pinIndicatorKey.currentState?.shake();
      return;
    }
    Navigator.of(context).pushReplacement(sharedAxisRoute(
      LoadProcessingScreen(amountPaise: widget.amountPaise),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enter UPI PIN')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          const SizedBox(height: AppSpacing.xl),
          Text('Enter UPI PIN', style: AppTypography.textTheme.headlineSmall, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.s),
          Text('6 digit PIN', style: AppTypography.textTheme.bodyMedium, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.xxl),
          PinIndicator(key: _pinIndicatorKey, length: _pinLength, filled: _pin.length),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.base),
            Text(
              _error!,
              key: const Key('upi-pin-error'),
              style: const TextStyle(color: AppColors.error),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: AppSpacing.xxxl),
          PinKeyboard(onDigit: _onDigit, onBackspace: _onBackspace),
          const SizedBox(height: AppSpacing.xxxl),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  key: const Key('upi-pin-cancel'),
                  label: 'Cancel',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: AppSpacing.base),
              Expanded(
                child: PrimaryButton(
                  key: const Key('upi-pin-verify'),
                  label: 'Verify',
                  onPressed: _onVerify,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
