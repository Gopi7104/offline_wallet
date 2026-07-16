import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline_wallet/app/home_screen.dart';
import 'package:offline_wallet/components/components.dart';
import 'package:offline_wallet/theme/theme.dart';
import 'security_provider.dart';

/// Create-PIN screen (Task 6.5): 6 digits, entered twice to confirm. Stored
/// as a salted hash via `PinService` — never plaintext.
///
/// [onComplete], when provided, replaces the default "go to Home" behavior —
/// used by Settings' "Change PIN" to return there instead.
class PinSetupScreen extends ConsumerStatefulWidget {
  final VoidCallback? onComplete;
  const PinSetupScreen({super.key, this.onComplete});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  final _indicatorKey = GlobalKey<PinIndicatorState>();
  String _firstEntry = '';
  String _current = '';
  bool _confirming = false;
  bool _saving = false;
  String? _error;

  void _onDigit(String digit) {
    if (_saving || _current.length >= 6) return;
    setState(() {
      _current += digit;
      _error = null;
    });
    if (_current.length == 6) _onSixDigits();
  }

  void _onBackspace() {
    if (_current.isEmpty) return;
    setState(() {
      _current = _current.substring(0, _current.length - 1);
      _error = null;
    });
  }

  Future<void> _onSixDigits() async {
    if (!_confirming) {
      setState(() {
        _firstEntry = _current;
        _current = '';
        _confirming = true;
      });
      return;
    }

    if (_current != _firstEntry) {
      _indicatorKey.currentState?.shake();
      setState(() {
        _current = '';
        _confirming = false;
        _firstEntry = '';
        _error = "PINs didn't match — try again";
      });
      return;
    }

    setState(() => _saving = true);
    await ref.read(pinServiceProvider).setPin(_current);
    ref.invalidate(pinSetProvider);
    if (!mounted) return;
    if (widget.onComplete != null) {
      widget.onComplete!();
    } else {
      Navigator.of(context).pushAndRemoveUntil(sharedAxisRoute(const HomeScreen()), (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            children: [
              const Spacer(),
              Text(
                _confirming ? 'Confirm your PIN' : 'Create a PIN',
                style: AppTypography.textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.s),
              Text(
                'Used to confirm offline payments',
                style: AppTypography.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xxl),
              PinIndicator(key: _indicatorKey, length: 6, filled: _current.length),
              const SizedBox(height: AppSpacing.base),
              SizedBox(
                height: 20,
                child: _error != null
                    ? Text(
                        _error!,
                        key: const Key('pin-setup-error'),
                        style: const TextStyle(color: AppColors.error),
                      )
                    : null,
              ),
              const Spacer(),
              PinKeyboard(onDigit: _onDigit, onBackspace: _onBackspace, enabled: !_saving),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}
