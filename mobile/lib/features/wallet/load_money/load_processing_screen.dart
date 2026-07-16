import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:offline_wallet/components/components.dart';
import 'package:offline_wallet/data/wallet_api_client.dart';
import 'package:offline_wallet/features/wallet/wallet_provider.dart';
import 'package:offline_wallet/features/wallet/wallet_screen.dart';
import 'package:offline_wallet/theme/theme.dart';
import 'load_success_screen.dart';

/// Processing — a brief "Verifying…" beat (UX pacing only, no real UPI
/// network call happens here) before actually calling the real backend
/// `POST /v1/wallet/load` endpoint that mints the tokens.
class LoadProcessingScreen extends ConsumerStatefulWidget {
  final int amountPaise;
  const LoadProcessingScreen({super.key, required this.amountPaise});

  @override
  ConsumerState<LoadProcessingScreen> createState() => _LoadProcessingScreenState();
}

class _LoadProcessingScreenState extends ConsumerState<LoadProcessingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _minDelay =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  bool _started = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    // Tied to a ticking AnimationController (frame-scheduled), not a bare
    // `Future.delayed` Timer, so `pumpAndSettle()` in widget tests waits it
    // out correctly instead of leaving a dangling timer.
    _minDelay.addStatusListener((status) {
      if (status == AnimationStatus.completed) _run();
    });
    _minDelay.forward();
  }

  @override
  void dispose() {
    _minDelay.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    if (_started) return;
    _started = true;
    try {
      // Best-effort backend record. A real validation error (e.g. the holding
      // cap) blocks the load; a network error does NOT — offline cash is
      // client-side in the prototype, so the wallet must load even with no
      // server reachable (a phone in the field).
      await ref.read(loadWalletProvider(widget.amountPaise).future);
    } on WalletApiException catch (error) {
      if (!mounted) return;
      await _showError(error);
      return;
    } catch (_) {
      // Backend unreachable — proceed offline and mint locally anyway.
    }

    // Task 8: minting is client-side — the load mints matching denomination
    // tokens into the local offline-cash wallet (the source of truth for
    // offline payments), which is persisted across restarts.
    ref.read(tokenWalletProvider.notifier).mint(widget.amountPaise);
    ref.invalidate(walletProvider);
    if (!mounted) return;
    final newBalancePaise = ref.read(tokenBalanceProvider).paise;
    Navigator.of(context).pushReplacement(sharedAxisRoute(
      LoadSuccessScreen(amountPaise: widget.amountPaise, newBalancePaise: newBalancePaise),
    ));
  }

  Future<void> _showError(Object error) async {
    String title = 'Server unavailable';
    String message = 'Could not reach the server. Check your connection and try again.';
    if (error is WalletApiException) {
      if (error.isHoldingCapExceeded) {
        title = 'Wallet limit exceeded';
        message = 'Your wallet cannot hold more than ₹50,000. Reduce the amount and try again.';
      } else {
        title = 'Load failed';
        message = error.message.isNotEmpty ? error.message : error.code;
      }
    }
    if (!mounted) return;
    // Stop the perpetually-spinning ring before opening the dialog — a
    // repeating `AnimationController` left mounted underneath a modal never
    // lets `pumpAndSettle()` in widget tests settle, even though the dialog
    // itself has nothing left animating (same class of bug as `LoadingOverlay`).
    setState(() => _failed = true);
    await showAppInfoDialog(context, title: title, message: message);
    if (!mounted) return;
    Navigator.of(context).popUntil(ModalRoute.withName(WalletScreen.routeName));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _failed
                ? const Icon(Symbols.error_outline_rounded, size: 64, color: AppColors.error)
                : const AnimatedLoading(size: 64),
            const SizedBox(height: AppSpacing.xl),
            Text(
              _failed ? 'Could not complete load' : 'Verifying…',
              key: const Key('processing-message'),
              style: AppTypography.textTheme.titleLarge,
            ),
          ],
        ),
      ),
    );
  }
}
