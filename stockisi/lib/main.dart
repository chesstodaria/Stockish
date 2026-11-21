import 'package:flutter/material.dart';

import 'app.dart';
import 'data/mock/mock_repositories.dart';
import 'data/mock/mock_seed.dart';
import 'services/session_store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Tahap UI: data dari repository tiruan di memori, sesi di perangkat.
  // Untuk pindah ke Supabase, ganti pembuatan `Repositories` di bawah
  // dengan implementasi Supabase. Layar tidak perlu diubah.
  final backend = createSeededBackend(failOnce: mockFailuresFromEnvironment());
  runApp(StockisiApp(
    repositories:
        createMockRepositories(backend, sessionStore: SecureSessionStore()),
  ));
}
