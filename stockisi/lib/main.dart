import 'package:flutter/material.dart';

import 'app.dart';
import 'data/mock/mock_repositories.dart';
import 'data/mock/mock_seed.dart';

void main() {
  // Tahap UI: semua data dari repository tiruan di memori. Untuk pindah ke
  // Supabase, ganti dua baris di bawah dengan pembuatan `Repositories`
  // berisi implementasi Supabase. Layar tidak perlu diubah.
  final backend = createSeededBackend(failOnce: mockFailuresFromEnvironment());
  runApp(StockisiApp(repositories: createMockRepositories(backend)));
}
