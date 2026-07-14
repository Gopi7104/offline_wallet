import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';

void main() {
  // ProviderScope is the Riverpod DI root (ADR-5).
  runApp(const ProviderScope(child: OfflineWalletApp()));
}
