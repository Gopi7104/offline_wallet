import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline_wallet/components/components.dart';
import 'biometric_service.dart';
import 'pin_service.dart';
import 'security_provider.dart';

/// Step-up authentication gate for a payment (Task 6.5): fingerprint first,
/// falling back to the app's own 6-digit PIN. This is the seam
/// `pay_flow_test.dart` overrides with a fake DI override.
abstract interface class PaymentStepUpAuthenticator {
  /// Returns true once the user has proven presence (biometric or correct
  /// PIN); false if they cancel or fail all attempts.
  Future<bool> authenticate(BuildContext context, {required String reason});
}

class DefaultPaymentStepUpAuthenticator implements PaymentStepUpAuthenticator {
  final BiometricService _biometrics;
  final PinService _pin;
  final bool Function() _biometricsEnabled;

  DefaultPaymentStepUpAuthenticator(
    this._biometrics,
    this._pin,
    this._biometricsEnabled,
  );

  @override
  Future<bool> authenticate(BuildContext context, {required String reason}) async {
    if (_biometricsEnabled() && await _biometrics.isAvailable()) {
      final ok = await _biometrics.authenticate(reason);
      if (ok) return true;
    }
    if (!context.mounted) return false;
    return _showPinSheet(context);
  }

  Future<bool> _showPinSheet(BuildContext context) async {
    final result = await showAppBottomSheet<bool>(
      context,
      isDismissible: true,
      builder: (context) => _PinStepUpSheet(pinService: _pin),
    );
    return result ?? false;
  }
}

class _PinStepUpSheet extends StatefulWidget {
  final PinService pinService;
  const _PinStepUpSheet({required this.pinService});

  @override
  State<_PinStepUpSheet> createState() => _PinStepUpSheetState();
}

class _PinStepUpSheetState extends State<_PinStepUpSheet> {
  final _indicatorKey = GlobalKey<PinIndicatorState>();
  String _entered = '';
  String? _error;
  bool _checking = false;
  int _attempts = 0;
  static const _maxAttempts = 5;

  Future<void> _onDigit(String digit) async {
    if (_checking || _entered.length >= 6) return;
    setState(() {
      _entered += digit;
      _error = null;
    });
    if (_entered.length == 6) {
      setState(() => _checking = true);
      final ok = await widget.pinService.verifyPin(_entered);
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pop(true);
        return;
      }
      _attempts++;
      _indicatorKey.currentState?.shake();
      setState(() {
        _entered = '';
        _checking = false;
        _error = _attempts >= _maxAttempts ? 'Too many attempts' : 'Incorrect PIN';
      });
      if (_attempts >= _maxAttempts) {
        Navigator.of(context).pop(false);
      }
    }
  }

  void _onBackspace() {
    if (_entered.isEmpty) return;
    setState(() {
      _entered = _entered.substring(0, _entered.length - 1);
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Enter PIN', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          'Confirm this payment with your PIN',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        PinIndicator(key: _indicatorKey, length: 6, filled: _entered.length),
        const SizedBox(height: 16),
        SizedBox(
          height: 20,
          child: _error != null
              ? Text(
                  _error!,
                  key: const Key('pin-stepup-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                )
              : null,
        ),
        const SizedBox(height: 16),
        PinKeyboard(onDigit: _onDigit, onBackspace: _onBackspace, enabled: !_checking),
      ],
    );
  }
}

final paymentStepUpAuthenticatorProvider = Provider<PaymentStepUpAuthenticator>((ref) {
  return DefaultPaymentStepUpAuthenticator(
    ref.watch(biometricServiceProvider),
    ref.watch(pinServiceProvider),
    () => ref.read(biometricsEnabledProvider),
  );
});
